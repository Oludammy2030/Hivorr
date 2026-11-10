// Minimal PNG codec used by the visual-regression gate (EP-01-004).
//
// Supports 8-bit, non-interlaced RGB and RGBA images, which is what the
// Playwright harness in EP-01-050 will produce. It deliberately implements only
// the PNG features the gate needs: no palette, no 16-bit, no interlacing.
//
// No dependency is added; `node:zlib` supplies compression.

import { deflateSync, inflateSync } from "node:zlib"

const SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])

const CRC_TABLE = (() => {
  const table = new Uint32Array(256)
  for (let index = 0; index < 256; index += 1) {
    let value = index
    for (let bit = 0; bit < 8; bit += 1) {
      value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1
    }
    table[index] = value >>> 0
  }
  return table
})()

function crc32(buffer) {
  let crc = 0xffffffff
  for (const byte of buffer) {
    crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8)
  }
  return (crc ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const typeBuffer = Buffer.from(type, "ascii")
  const length = Buffer.alloc(4)
  length.writeUInt32BE(data.length, 0)
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuffer, data])), 0)
  return Buffer.concat([length, typeBuffer, data, crc])
}

export function encodePng({ width, height, channels, data }) {
  if (channels !== 3 && channels !== 4) {
    throw new Error("encodePng: channels must be 3 (RGB) or 4 (RGBA)")
  }
  if (data.length !== width * height * channels) {
    throw new Error("encodePng: data length does not match dimensions")
  }

  const header = Buffer.alloc(13)
  header.writeUInt32BE(width, 0)
  header.writeUInt32BE(height, 4)
  header[8] = 8
  header[9] = channels === 4 ? 6 : 2
  header[10] = 0
  header[11] = 0
  header[12] = 0

  const stride = width * channels
  const raw = Buffer.alloc(height * (stride + 1))
  for (let row = 0; row < height; row += 1) {
    const target = row * (stride + 1)
    raw[target] = 0
    Buffer.from(data.buffer, data.byteOffset + row * stride, stride).copy(
      raw,
      target + 1,
    )
  }

  return Buffer.concat([
    SIGNATURE,
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(raw)),
    chunk("IEND", Buffer.alloc(0)),
  ])
}

function paeth(a, b, c) {
  const p = a + b - c
  const pa = Math.abs(p - a)
  const pb = Math.abs(p - b)
  const pc = Math.abs(p - c)
  if (pa <= pb && pa <= pc) return a
  if (pb <= pc) return b
  return c
}

export function decodePng(buffer) {
  const source = Buffer.from(buffer)
  if (
    source.length < SIGNATURE.length ||
    !source.subarray(0, SIGNATURE.length).equals(SIGNATURE)
  ) {
    throw new Error("decodePng: not a PNG file")
  }

  let offset = SIGNATURE.length
  let header = null
  const idat = []

  while (offset + 8 <= source.length) {
    const length = source.readUInt32BE(offset)
    const type = source.toString("ascii", offset + 4, offset + 8)
    const start = offset + 8
    const end = start + length
    if (end + 4 > source.length) {
      throw new Error(`decodePng: truncated ${type} chunk`)
    }
    const data = source.subarray(start, end)
    if (type === "IHDR") {
      header = {
        width: data.readUInt32BE(0),
        height: data.readUInt32BE(4),
        bitDepth: data[8],
        colorType: data[9],
        compression: data[10],
        filter: data[11],
        interlace: data[12],
      }
    } else if (type === "IDAT") {
      idat.push(Buffer.from(data))
    } else if (type === "IEND") {
      break
    }
    offset = end + 4
  }

  if (!header) throw new Error("decodePng: IHDR chunk missing")
  if (header.bitDepth !== 8) {
    throw new Error(`decodePng: unsupported bit depth ${header.bitDepth}`)
  }
  if (header.interlace !== 0) {
    throw new Error("decodePng: interlaced images are not supported")
  }
  if (header.colorType !== 2 && header.colorType !== 6) {
    throw new Error(`decodePng: unsupported colour type ${header.colorType}`)
  }

  const channels = header.colorType === 6 ? 4 : 3
  const stride = header.width * channels
  const inflated = inflateSync(Buffer.concat(idat))
  const expected = header.height * (stride + 1)
  if (inflated.length < expected) {
    throw new Error("decodePng: image data is shorter than the header declares")
  }

  const data = new Uint8Array(header.height * stride)
  const bpp = channels

  for (let row = 0; row < header.height; row += 1) {
    const rawStart = row * (stride + 1)
    const filter = inflated[rawStart]
    const target = row * stride
    const prior = target - stride

    for (let column = 0; column < stride; column += 1) {
      const raw = inflated[rawStart + 1 + column]
      const left = column >= bpp ? data[target + column - bpp] : 0
      const up = row > 0 ? data[prior + column] : 0
      const upLeft = row > 0 && column >= bpp ? data[prior + column - bpp] : 0
      let value
      switch (filter) {
        case 0:
          value = raw
          break
        case 1:
          value = raw + left
          break
        case 2:
          value = raw + up
          break
        case 3:
          value = raw + Math.floor((left + up) / 2)
          break
        case 4:
          value = raw + paeth(left, up, upLeft)
          break
        default:
          throw new Error(`decodePng: unknown row filter ${filter}`)
      }
      data[target + column] = value & 0xff
    }
  }

  return { width: header.width, height: header.height, channels, data }
}
