module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2020,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
  },
  overrides: [
    {
      files: ["index.js"],
      rules: {
        "require-jsdoc": "off",
        "valid-jsdoc": "off",
        "max-len": "off",
        "indent": "off",
        "object-curly-spacing": "off",
        "comma-dangle": "off",
        "operator-linebreak": "off",
        "no-trailing-spaces": "off",
        "no-multiple-empty-lines": "off",
        "eol-last": "off",
        "no-multi-spaces": "off",
        "no-constant-condition": "off",
        "no-unused-vars": "off",
      },
    },
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
    {
      files: ["**/*.test.js"],
      env: {
        jest: true,
      },
      rules: {
        "indent": "off",
        "max-len": "off",
      },
    },
  ],
  globals: {},
};
