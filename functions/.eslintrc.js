module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
  extends: ["eslint:recommended", "plugin:import/recommended", "prettier"],
  rules: {
    "import/no-unresolved": 0,
  },
};
