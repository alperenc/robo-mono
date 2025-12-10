import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const lcovPath = path.join(__dirname, "../lcov.info");

function parseLcov(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: File not found at ${filePath}`);
    process.exit(1);
  }

  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.split("\n");
  const files = {};
  let currentFile = null;

  lines.forEach((line) => {
    line = line.trim();
    if (line === "") return;

    if (line.startsWith("SF:")) {
      currentFile = line.substring(3);
      files[currentFile] = {
        lines: { total: 0, hit: 0 },
        functions: { total: 0, hit: 0, details: [] },
        branches: { total: 0, hit: 0, details: [] },
      };
    } else if (currentFile) {
      if (line.startsWith("FN:")) {
        const parts = line.split(",");
        const name = parts[1];
        files[currentFile].functions.details.push({ name, hit: false });
      } else if (line.startsWith("FNDA:")) {
        const parts = line.split(",");
        const count = parseInt(parts[0].split(":")[1]);
        const name = parts[1];
        const func = files[currentFile].functions.details.find(
          (f) => f.name === name
        );
        if (func && count > 0) func.hit = true;
      } else if (line.startsWith("BRDA:")) {
        const parts = line.split(",");
        const lineNum = parseInt(parts[0].split(":")[1]);
        const taken = parts[3] !== "-" && parseInt(parts[3]) > 0;
        files[currentFile].branches.details.push({ line: lineNum, taken });
      }
    }
  });

  return files;
}

function analyzeCoverage() {
  console.log("Coverage Analysis Report");
  console.log("========================\n");

  const coverageData = parseLcov(lcovPath);
  let hasIssues = false;

  for (const [file, data] of Object.entries(coverageData)) {
    // Filter for contracts only, excluding tests and scripts
    if (
      !file.includes("contracts/") ||
      file.includes(".t.sol") ||
      file.includes(".s.sol")
    ) {
      continue;
    }

    const relativePath = file.split("protocols/evm/")[1] || file;
    const uncoveredFunctions = data.functions.details.filter((f) => !f.hit);
    const uncoveredBranches = data.branches.details.filter((b) => !b.taken);

    if (uncoveredFunctions.length > 0 || uncoveredBranches.length > 0) {
      hasIssues = true;
      console.log(`File: ${relativePath}`);

      if (uncoveredFunctions.length > 0) {
        console.log("  Uncovered Functions:");
        uncoveredFunctions.forEach((f) => console.log(`    - ${f.name}`));
      }

      if (uncoveredBranches.length > 0) {
        console.log("  Uncovered Branches:");
        // Group branches by line to avoid spam
        const branchesByLine = {};
        uncoveredBranches.forEach((b) => {
          branchesByLine[b.line] = (branchesByLine[b.line] || 0) + 1;
        });

        for (const [line, count] of Object.entries(branchesByLine)) {
          console.log(`    - Line ${line}: ${count} branch(es) not taken`);
        }
      }
      console.log("");
    }
  }

  if (!hasIssues) {
    console.log(
      "All contracts have 100% function and branch coverage (or are filtered out)."
    );
  }
}

// Run if called directly
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  analyzeCoverage();
}

export { analyzeCoverage };
