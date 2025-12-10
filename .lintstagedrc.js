const path = require("path");

const buildWebEslintCommand = (filenames) =>
  `yarn web:lint --fix --file ${filenames
    .map((f) => path.relative(path.join("web"), f))
    .join(" --file ")}`;

const checkTypesWebCommand = () => "yarn web:check-types";

// const buildEvmEslintCommand = (filenames) =>
//   `yarn evm:lint --fix ${filenames
//     .map((f) => path.relative(path.join("protocols", "evm"), f))
//     .join(" ")}`;

module.exports = {
  "web/**/*.{ts,tsx}": [
    buildWebEslintCommand,
    checkTypesWebCommand,
  ],
  "protocols/evm/**/*.{js,ts,sol}": [
    "yarn workspace evm format",
    "yarn workspace evm lint",
  ],
};
