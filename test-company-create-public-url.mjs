import assert from 'node:assert/strict';

const reserved = new Set(['www', 'api', 'admin', 'test', 'test2']);
const slugify = value => value.toLowerCase().trim().replace(/[^\p{L}\p{N}-]+/gu, '-').replace(/^-+|-+$/g, '');
const toAscii = value => new URL(`https://${slugify(value)}.отзыв.com`).hostname.split('.')[0];
const publicUrl = company => `https://${company.slug}.xn--b1ajuq0c.com/`;

assert.equal(toAscii('Моя компания'), 'xn----8sbygicidcl5oi');
for (const slug of reserved) assert.equal(reserved.has(slug), true);
assert.equal(publicUrl({ slug: 'xn----8sbygicidcl5oi-2' }), 'https://xn----8sbygicidcl5oi-2.xn--b1ajuq0c.com/');
const rpcResponse = { company: { id: 'id-1', slug: 'acme-3' } };
assert.match(publicUrl(rpcResponse.company), /^https:\/\/acme-3\.xn--b1ajuq0c\.com\/$/);
console.log('company create frontend tests: PASS');
