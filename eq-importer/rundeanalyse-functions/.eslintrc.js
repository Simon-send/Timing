module.exports = {
  env: {
    es2022: true,
    node: true,
  },
  extends: ["eslint:recommended", "google"],
  parserOptions: {
    ecmaVersion: 2022,
  },
  rules: {
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
    "max-len": "off",
    "indent": "off",
    "linebreak-style": "off",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
  },
  overrides: [
    {
      files: ["__tests__/**/*.test.js"],
      env: {
        jest: true,
      },
      rules: {
        "max-len": "off",
      },
    },
  ],
};
