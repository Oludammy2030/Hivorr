import { useEffect, useState, type FormEvent } from "react"

import {
  api,
  errorMessage,
  type TaxonomyAttribute,
  type TaxonomyNode,
  type TaxonomyRegistry,
} from "./api"

interface TaxonomyPageProps {
  canManage: boolean
}

function nodeLabel(node: TaxonomyNode): string {
  return `${node.name} (${node.level})`
}

export function TaxonomyPage({ canManage }: TaxonomyPageProps) {
  const [registry, setRegistry] = useState<TaxonomyRegistry | null>(null)
  const [taxonomy, setTaxonomy] = useState<"profession" | "product">(
    "profession",
  )
  const [selectedNode, setSelectedNode] = useState("")
  const [error, setError] = useState<string | undefined>()
  const [busy, setBusy] = useState(false)

  async function refresh(next: "profession" | "product" = taxonomy) {
    const value = await api.listTaxonomy(next)
    setRegistry(value)
    setSelectedNode((current) => current || value.nodes[0]?.id || "")
  }

  useEffect(() => {
    let active = true
    setBusy(true)
    api
      .listTaxonomy(taxonomy)
      .then((value) => {
        if (!active) return
        setRegistry(value)
        setSelectedNode((current) => current || value.nodes[0]?.id || "")
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
      .finally(() => {
        if (active) setBusy(false)
      })
    return () => {
      active = false
    }
  }, [taxonomy])

  async function handleCreateNode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const name = String(form.get("name") ?? "").trim()
    const slug = String(form.get("slug") ?? "").trim()
    const level = String(form.get("level") ?? "")
    const parentId = String(form.get("parentId") ?? "").trim() || null
    const reason = String(form.get("reason") ?? "").trim()
    if (!name || !slug || !level || reason.length < 5) {
      setError(
        "A name, slug, level and reason of at least five characters are required.",
      )
      return
    }
    setBusy(true)
    setError(undefined)
    try {
      await api.createTaxonomyNode({
        taxonomy,
        level,
        parentId,
        slug,
        name,
        description: String(form.get("description") ?? "").trim() || undefined,
        version: Number(form.get("version") ?? 1) || 1,
        effectiveFrom:
          String(form.get("effectiveFrom") ?? "").trim() || undefined,
        reason,
      })
      event.currentTarget.reset()
      await refresh()
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleCreateAttribute(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const nodeId = String(form.get("nodeId") ?? "").trim()
    const key = String(form.get("key") ?? "").trim()
    const label = String(form.get("label") ?? "").trim()
    const dataType = String(form.get("dataType") ?? "text")
    const reason = String(form.get("reason") ?? "").trim()
    const enumRaw = String(form.get("enumValues") ?? "").trim()
    if (!nodeId || !key || !label || reason.length < 5) {
      setError(
        "A node, key, label and reason of at least five characters are required.",
      )
      return
    }
    setBusy(true)
    setError(undefined)
    try {
      await api.createTaxonomyAttribute({
        nodeId,
        key,
        label,
        dataType,
        isRequired: form.get("isRequired") === "on",
        enumValues:
          dataType === "enum"
            ? enumRaw
                .split(",")
                .map((entry) => entry.trim())
                .filter(Boolean)
            : null,
        unit: String(form.get("unit") ?? "").trim() || undefined,
        reason,
      })
      event.currentTarget.reset()
      await refresh()
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  const nodes = registry?.nodes ?? []
  const attributes = registry?.attributes ?? []
  const selectedAttributes = attributes.filter(
    (entry) => entry.nodeId === selectedNode,
  )

  return (
    <section className="page">
      <header className="page-head">
        <div>
          <p className="eyebrow">Configuration</p>
          <h1>Taxonomy</h1>
          <p className="muted">
            Profession and product classifications. Writes are versioned,
            effective-dated and audited.
          </p>
        </div>
        <label className="field field-inline">
          <span>Taxonomy</span>
          <select
            value={taxonomy}
            onChange={(event) => {
              setTaxonomy(event.target.value as "profession" | "product")
              setSelectedNode("")
            }}
          >
            <option value="profession">Profession</option>
            <option value="product">Product</option>
          </select>
        </label>
      </header>

      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}

      <div className="grid-two">
        <section className="panel">
          <h2>Nodes</h2>
          {busy && <p className="muted">Loading…</p>}
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Level</th>
                <th>Version</th>
                <th>Active</th>
              </tr>
            </thead>
            <tbody>
              {nodes.map((node) => (
                <tr
                  key={node.id}
                  className={node.id === selectedNode ? "selected" : undefined}
                  onClick={() => setSelectedNode(node.id)}
                >
                  <td>{nodeLabel(node)}</td>
                  <td>{node.slug}</td>
                  <td>{node.version}</td>
                  <td>{node.isActive ? "Yes" : "No"}</td>
                </tr>
              ))}
              {nodes.length === 0 && (
                <tr>
                  <td colSpan={4}>No nodes yet.</td>
                </tr>
              )}
            </tbody>
          </table>
        </section>

        <section className="panel">
          <h2>Attributes {selectedNode ? "" : "(select a node)"}</h2>
          <table className="table">
            <thead>
              <tr>
                <th>Key</th>
                <th>Type</th>
                <th>Required</th>
              </tr>
            </thead>
            <tbody>
              {selectedAttributes.map((attribute: TaxonomyAttribute) => (
                <tr key={attribute.id}>
                  <td>{attribute.key}</td>
                  <td>{attribute.dataType}</td>
                  <td>{attribute.isRequired ? "Yes" : "No"}</td>
                </tr>
              ))}
              {selectedAttributes.length === 0 && (
                <tr>
                  <td colSpan={3}>No attributes on this node.</td>
                </tr>
              )}
            </tbody>
          </table>
        </section>
      </div>

      {canManage && (
        <div className="grid-two">
          <form className="panel form" onSubmit={handleCreateNode}>
            <h2>Add node</h2>
            <label className="field">
              <span>Name</span>
              <input name="name" required maxLength={160} />
            </label>
            <label className="field">
              <span>Slug</span>
              <input name="slug" required pattern="[a-z0-9-]+" />
            </label>
            <label className="field">
              <span>Level</span>
              <select name="level" required>
                {taxonomy === "profession" ? (
                  <>
                    <option value="industry">Industry</option>
                    <option value="profession">Profession</option>
                  </>
                ) : (
                  <>
                    <option value="vertical">Vertical</option>
                    <option value="category">Category</option>
                    <option value="subcategory">Subcategory</option>
                    <option value="product_type">Product type</option>
                  </>
                )}
              </select>
            </label>
            <label className="field">
              <span>Parent</span>
              <select name="parentId">
                <option value="">No parent (root)</option>
                {nodes.map((node) => (
                  <option key={node.id} value={node.id}>
                    {nodeLabel(node)}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Description</span>
              <textarea name="description" rows={2} maxLength={2000} />
            </label>
            <label className="field">
              <span>Version</span>
              <input name="version" type="number" min={1} defaultValue={1} />
            </label>
            <label className="field">
              <span>Effective from</span>
              <input name="effectiveFrom" type="datetime-local" />
            </label>
            <label className="field">
              <span>Reason</span>
              <input name="reason" required minLength={5} />
            </label>
            <button className="button" type="submit" disabled={busy}>
              Add node
            </button>
          </form>

          <form className="panel form" onSubmit={handleCreateAttribute}>
            <h2>Add attribute</h2>
            <label className="field">
              <span>Node</span>
              <select
                name="nodeId"
                value={selectedNode}
                onChange={(event) => setSelectedNode(event.target.value)}
                required
              >
                <option value="">Select a node</option>
                {nodes.map((node) => (
                  <option key={node.id} value={node.id}>
                    {nodeLabel(node)}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              <span>Key</span>
              <input name="key" required pattern="[a-z][a-z0-9_]*" />
            </label>
            <label className="field">
              <span>Label</span>
              <input name="label" required maxLength={120} />
            </label>
            <label className="field">
              <span>Type</span>
              <select name="dataType" defaultValue="text">
                <option value="text">Text</option>
                <option value="number">Number</option>
                <option value="boolean">Boolean</option>
                <option value="enum">Enum</option>
                <option value="date">Date</option>
              </select>
            </label>
            <label className="field">
              <span>Enum values (comma separated)</span>
              <input name="enumValues" />
            </label>
            <label className="field field-check">
              <input name="isRequired" type="checkbox" />
              <span>Required</span>
            </label>
            <label className="field">
              <span>Unit</span>
              <input name="unit" maxLength={40} />
            </label>
            <label className="field">
              <span>Reason</span>
              <input name="reason" required minLength={5} />
            </label>
            <button className="button" type="submit" disabled={busy}>
              Add attribute
            </button>
          </form>
        </div>
      )}
    </section>
  )
}
