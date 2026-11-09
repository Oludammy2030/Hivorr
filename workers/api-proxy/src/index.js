/**
 * Same-origin /api proxy for the staging hosts.
 *
 * The browser calls /api/* on an application host. This Worker strips the
 * /api prefix, forwards the request to the Fly API, and preserves the original
 * application host so the API resolves the correct portal. Only this Worker
 * knows the edge secret; a direct caller cannot choose another portal.
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url)
    if (!url.pathname.startsWith("/api/")) {
      return new Response("Not found", { status: 404 })
    }

    const target = new URL(env.API_ORIGIN)
    target.pathname = url.pathname.slice("/api".length)
    target.search = url.search

    const headers = new Headers(request.headers)
    headers.set("x-hivorr-origin-host", url.hostname)
    headers.set("x-hivorr-edge-secret", env.EDGE_SHARED_SECRET)
    headers.set("x-forwarded-proto", "https")
    const clientIp = request.headers.get("cf-connecting-ip")
    if (clientIp) headers.set("x-forwarded-for", clientIp)

    const upstream = await fetch(target.toString(), {
      method: request.method,
      headers,
      body:
        request.method === "GET" || request.method === "HEAD"
          ? undefined
          : request.body,
      redirect: "manual",
    })

    const responseHeaders = new Headers(upstream.headers)
    const cookies =
      typeof upstream.headers.getSetCookie === "function"
        ? upstream.headers.getSetCookie()
        : []
    responseHeaders.delete("set-cookie")
    for (const cookie of cookies) {
      responseHeaders.append("set-cookie", cookie)
    }

    return new Response(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: responseHeaders,
    })
  },
}
