#!/usr/bin/env node
// OpenAPI breaking-change gate (EP-01-004).
//
// Compares the base and head OpenAPI documents and writes a reviewable report.
// The document is published by EP-01-013; until then the gate is dormant and
// says so rather than reporting a false pass.
//
// Supported input: JSON. EP-01-013 owns the generator and can add YAML here if
// the generator emits it.
//
// Usage:
//   node scripts/openapi-diff.mjs --base <file> --head <file> --fail-on-breaking
//   node scripts/openapi-diff.mjs --base <file> --head <file> --out report.md

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import path from "node:path"

const HTTP_METHODS = [
  "get",
  "put",
  "post",
  "delete",
  "options",
  "head",
  "patch",
  "trace",
]

const args = process.argv.slice(2)
let basePath = ""
let headPath = ""
let out = ""
let failOnBreaking = false
let failOnAny = false

for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--base" && args[index + 1]) {
    basePath = args[index + 1]
    index += 1
  } else if (args[index] === "--head" && args[index + 1]) {
    headPath = args[index + 1]
    index += 1
  } else if (args[index] === "--out" && args[index + 1]) {
    out = args[index + 1]
    index += 1
  } else if (args[index] === "--fail-on-breaking") {
    failOnBreaking = true
  } else if (args[index] === "--fail-on-any") {
    failOnAny = true
  }
}

function reportAndExit(markdown) {
  if (out) {
    mkdirSync(path.dirname(path.resolve(out)), { recursive: true })
    writeFileSync(out, `${markdown}\n`)
    console.log(`openapi:diff: wrote ${out}`)
  } else {
    console.log(markdown)
  }
}

function load(file) {
  if (!file || !existsSync(file)) return null
  const raw = readFileSync(file, "utf8").trim()
  if (!raw || raw === "{}") return null
  try {
    return { doc: JSON.parse(raw), file }
  } catch (error) {
    console.error(
      `openapi:diff: ${file} is not valid JSON: ${
        error instanceof Error ? error.message : String(error)
      }`,
    )
    process.exit(2)
  }
}

const base = load(basePath)
const head = load(headPath)

if (!head) {
  reportAndExit(
    [
      "# OpenAPI diff",
      "",
      `No OpenAPI document at \`${headPath || "(unset)"}\`.`,
      "The gate is **dormant** until EP-01-013 publishes the first contract.",
      "",
    ].join("\n"),
  )
  process.exit(0)
}

if (!base) {
  reportAndExit(
    [
      "# OpenAPI diff",
      "",
      `No base document at \`${basePath || "(unset)"}\`; \`${head.file}\` is the first contract.`,
      "A first document cannot break a previous contract.",
      "",
    ].join("\n"),
  )
  process.exit(0)
}

const findings = []

function add(severity, where, message) {
  findings.push({ severity, where, message })
}

function resolve(doc, value) {
  if (!value || typeof value !== "object" || typeof value.$ref !== "string") {
    return value
  }
  if (!value.$ref.startsWith("#/")) return value
  let cursor = doc
  for (const part of value.$ref.slice(2).split("/")) {
    cursor = cursor?.[part.replace(/~1/g, "/").replace(/~0/g, "~")]
  }
  return cursor ?? value
}

function compareSchema(baseDoc, headDoc, baseValue, headValue, where, seen) {
  const left = resolve(baseDoc, baseValue)
  const right = resolve(headDoc, headValue)
  if (
    !left ||
    !right ||
    typeof left !== "object" ||
    typeof right !== "object"
  ) {
    return
  }

  const refKey = `${baseValue?.$ref ?? ""}|${headValue?.$ref ?? ""}|${where}`
  if (seen.has(refKey)) return
  seen.add(refKey)

  const leftType = Array.isArray(left.type) ? left.type.join("|") : left.type
  const rightType = Array.isArray(right.type)
    ? right.type.join("|")
    : right.type
  if (leftType && rightType && leftType !== rightType) {
    add(
      "breaking",
      where,
      `type changed from \`${leftType}\` to \`${rightType}\``,
    )
  }

  if (Array.isArray(left.enum) && Array.isArray(right.enum)) {
    for (const value of left.enum) {
      if (!right.enum.some((candidate) => candidate === value)) {
        add(
          "breaking",
          where,
          `enum value \`${JSON.stringify(value)}\` was removed`,
        )
      }
    }
    for (const value of right.enum) {
      if (!left.enum.some((candidate) => candidate === value)) {
        add(
          "non-breaking",
          where,
          `enum value \`${JSON.stringify(value)}\` was added`,
        )
      }
    }
  } else if (Array.isArray(left.enum) && !Array.isArray(right.enum)) {
    add("non-breaking", where, "enum constraint was removed")
  }

  if (left.type === "array" && right.type === "array") {
    compareSchema(baseDoc, headDoc, left.items, right.items, `${where}[]`, seen)
  }

  if (
    (left.type === "object" || left.properties) &&
    (right.type === "object" || right.properties)
  ) {
    const leftProps = left.properties ?? {}
    const rightProps = right.properties ?? {}

    for (const name of Object.keys(leftProps)) {
      if (!(name in rightProps)) {
        add("breaking", `${where}.${name}`, "property was removed")
      } else {
        compareSchema(
          baseDoc,
          headDoc,
          leftProps[name],
          rightProps[name],
          `${where}.${name}`,
          seen,
        )
      }
    }

    const leftRequired = new Set(left.required ?? [])
    const rightRequired = new Set(right.required ?? [])
    for (const name of rightRequired) {
      if (!leftRequired.has(name)) {
        add("breaking", `${where}.${name}`, "property became required")
      }
    }
    for (const name of leftRequired) {
      if (!rightRequired.has(name)) {
        add(
          "non-breaking",
          `${where}.${name}`,
          "property stopped being required",
        )
      }
    }
    for (const name of Object.keys(rightProps)) {
      if (!(name in leftProps)) {
        add("non-breaking", `${where}.${name}`, "property was added")
      }
    }
  }
}

function parametersOf(operation) {
  const map = new Map()
  for (const parameter of operation?.parameters ?? []) {
    if (!parameter || typeof parameter !== "object") continue
    const key = `${parameter.in ?? "?"}:${parameter.name ?? "?"}`
    map.set(key, parameter)
  }
  return map
}

function compareOperation(baseDoc, headDoc, pathName, method, baseOp, headOp) {
  const where = `${method.toUpperCase()} ${pathName}`
  const baseParams = parametersOf(baseOp)
  const headParams = parametersOf(headOp)

  for (const [key, parameter] of baseParams) {
    if (!headParams.has(key)) {
      add("breaking", where, `parameter \`${key}\` was removed`)
    } else {
      compareSchema(
        baseDoc,
        headDoc,
        parameter.schema,
        headParams.get(key).schema,
        `${where} parameter ${key}`,
        new Set(),
      )
    }
  }
  for (const [key, parameter] of headParams) {
    if (!baseParams.has(key) && parameter.required === true) {
      add("breaking", where, `required parameter \`${key}\` was added`)
    } else if (!baseParams.has(key)) {
      add("non-breaking", where, `optional parameter \`${key}\` was added`)
    }
  }

  const baseBody = baseOp?.requestBody
  const headBody = headOp?.requestBody
  if (!baseBody && headBody?.required === true) {
    add("breaking", where, "a required request body was added")
  }
  if (baseBody?.required !== true && headBody?.required === true) {
    add("breaking", where, "request body became required")
  }
  if (baseBody?.content && headBody?.content) {
    for (const mediaType of Object.keys(baseBody.content)) {
      const left = baseBody.content[mediaType]?.schema
      const right = headBody.content[mediaType]?.schema
      if (!right) {
        add(
          "breaking",
          where,
          `request media type \`${mediaType}\` was removed`,
        )
      } else {
        compareSchema(
          baseDoc,
          headDoc,
          left,
          right,
          `${where} request ${mediaType}`,
          new Set(),
        )
      }
    }
  }

  const baseResponses = baseOp?.responses ?? {}
  const headResponses = headOp?.responses ?? {}
  for (const status of Object.keys(baseResponses)) {
    if (!(status in headResponses)) {
      add("breaking", where, `response \`${status}\` was removed`)
      continue
    }
    const leftContent = baseResponses[status]?.content ?? {}
    const rightContent = headResponses[status]?.content ?? {}
    for (const mediaType of Object.keys(leftContent)) {
      if (!(mediaType in rightContent)) {
        add(
          "breaking",
          where,
          `response \`${status}\` media type \`${mediaType}\` was removed`,
        )
      } else {
        compareSchema(
          baseDoc,
          headDoc,
          leftContent[mediaType]?.schema,
          rightContent[mediaType]?.schema,
          `${where} response ${status} ${mediaType}`,
          new Set(),
        )
      }
    }
  }
}

const basePaths = base.doc.paths ?? {}
const headPaths = head.doc.paths ?? {}

for (const pathName of Object.keys(basePaths)) {
  if (!(pathName in headPaths)) {
    add("breaking", pathName, "path was removed")
    continue
  }
  for (const method of HTTP_METHODS) {
    if (!basePaths[pathName]?.[method]) continue
    if (!headPaths[pathName]?.[method]) {
      add("breaking", pathName, `${method.toUpperCase()} operation was removed`)
      continue
    }
    compareOperation(
      base.doc,
      head.doc,
      pathName,
      method,
      basePaths[pathName][method],
      headPaths[pathName][method],
    )
  }
}

for (const pathName of Object.keys(headPaths)) {
  if (!(pathName in basePaths)) {
    add("non-breaking", pathName, "path was added")
  }
}

const baseSchemas = base.doc.components?.schemas ?? {}
const headSchemas = head.doc.components?.schemas ?? {}
for (const name of Object.keys(baseSchemas)) {
  if (!(name in headSchemas)) {
    add("breaking", `components.schemas.${name}`, "schema was removed")
  } else {
    compareSchema(
      base.doc,
      head.doc,
      baseSchemas[name],
      headSchemas[name],
      `components.schemas.${name}`,
      new Set(),
    )
  }
}

const breaking = findings.filter((finding) => finding.severity === "breaking")
const additive = findings.filter((finding) => finding.severity !== "breaking")

const report = [
  "# OpenAPI diff",
  "",
  `- Base: \`${base.file}\``,
  `- Head: \`${head.file}\``,
  `- Breaking changes: **${breaking.length}**`,
  `- Additive changes: **${additive.length}**`,
  "",
  "## Breaking changes",
  "",
  ...(breaking.length
    ? breaking.map((finding) => `- \`${finding.where}\` — ${finding.message}`)
    : ["_None._"]),
  "",
  "## Additive changes",
  "",
  ...(additive.length
    ? additive.map((finding) => `- \`${finding.where}\` — ${finding.message}`)
    : ["_None._"]),
  "",
].join("\n")

reportAndExit(report)

if (failOnBreaking && breaking.length) {
  console.error(
    `openapi:diff: ${breaking.length} breaking change(s) fail the gate`,
  )
  process.exit(1)
}
if (failOnAny && findings.length) {
  console.error(`openapi:diff: ${findings.length} change(s) fail the gate`)
  process.exit(1)
}
