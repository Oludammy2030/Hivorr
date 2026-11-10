export interface RateLimitOptions {
  readonly windowMs: number
  readonly max: number
}

export interface RateLimitResult {
  readonly allowed: boolean
  readonly retryAfterSeconds: number
  readonly remaining: number
}

interface Bucket {
  count: number
  resetAt: number
}

/**
 * Fixed-window limiter for authentication abuse controls (EP-01-042).
 *
 * In-memory by design: one API process. A multi-instance deployment needs a
 * shared store (Redis or Postgres); the interface is the seam for that change.
 * The map is pruned opportunistically so many identifiers cannot grow it
 * without bound.
 */
export class FixedWindowRateLimiter {
  private readonly buckets = new Map<string, Bucket>()
  private readonly maxBuckets: number

  constructor(maxBuckets = 10_000) {
    this.maxBuckets = maxBuckets
  }

  check(
    key: string,
    options: RateLimitOptions,
    now = Date.now(),
  ): RateLimitResult {
    const existing = this.buckets.get(key)
    if (!existing || existing.resetAt <= now) {
      this.buckets.set(key, {
        count: 1,
        resetAt: now + Math.max(1, options.windowMs),
      })
      this.prune(now)
      return {
        allowed: true,
        retryAfterSeconds: 0,
        remaining: Math.max(0, options.max - 1),
      }
    }

    if (existing.count >= options.max) {
      return {
        allowed: false,
        retryAfterSeconds: Math.max(
          1,
          Math.ceil((existing.resetAt - now) / 1_000),
        ),
        remaining: 0,
      }
    }

    existing.count += 1
    return {
      allowed: true,
      retryAfterSeconds: 0,
      remaining: Math.max(0, options.max - existing.count),
    }
  }

  reset(): void {
    this.buckets.clear()
  }

  private prune(now: number): void {
    if (this.buckets.size <= this.maxBuckets) return
    for (const [key, bucket] of this.buckets) {
      if (bucket.resetAt <= now) this.buckets.delete(key)
    }
  }
}
