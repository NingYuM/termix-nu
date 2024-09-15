import fs from 'node:fs'
import crypto from 'node:crypto'
import { base32 } from 'rfc4648'

export function createBase32Hash (str) {
  return base32.stringify(crypto.createHash('md5').update(str).digest()).replace(/(=+)$/, '').toLowerCase()
}

export async function createBase32HashFromFile (file) {
  const content = await fs.promises.readFile(file, 'utf8')
  return createBase32Hash(content.split('\r\n').join('\n'))
}

const fileName = process.argv[2];
if (!fileName) {
  console.error('请提供需要进行 base32hash 的文件名');
  process.exit(1);
}
const hash = await createBase32HashFromFile(fileName);
console.log(hash);
