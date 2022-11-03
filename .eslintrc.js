module.exports = {
  extends: ['prettier', 'plugin:yml/standard'],
  rules: { 'yml/quotes': ['error', { prefer: 'single' }] },
};
