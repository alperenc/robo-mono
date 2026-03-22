import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const lcovPath = path.join(__dirname, "../lcov.info");
const waiversPath = path.join(__dirname, "./coverage-waivers.json");

function getEvmRoot() {
  return path.resolve(__dirname, "..");
}

function getAbsoluteContractPath(relativeContractPath) {
  return path.join(getEvmRoot(), relativeContractPath);
}

function findLineBySnippet(relativeContractPath, sourceIncludes) {
  if (!sourceIncludes) return null;

  const absolutePath = getAbsoluteContractPath(relativeContractPath);
  if (!fs.existsSync(absolutePath)) {
    return null;
  }

  const fileLines = fs.readFileSync(absolutePath, "utf-8").split("\n");
  const matches = [];

  fileLines.forEach((line, index) => {
    if (line.includes(sourceIncludes)) {
      matches.push(index + 1);
    }
  });

  if (matches.length === 1) {
    return matches[0];
  }

  return null;
}

function loadWaivers(filePath) {
  if (!fs.existsSync(filePath)) {
    return { lineWaivers: new Map(), functionWaivers: new Map() };
  }

  const raw = JSON.parse(fs.readFileSync(filePath, "utf-8"));
  const lineWaivers = new Map();
  const functionWaivers = new Map();

  raw.forEach((waiver) => {
    if (waiver.function) {
      functionWaivers.set(`${waiver.file}:${waiver.function}`, waiver);
      return;
    }

    const resolvedLine = findLineBySnippet(waiver.file, waiver.sourceIncludes);
    const line = resolvedLine ?? waiver.line;

    if (line == null) {
      return;
    }

    lineWaivers.set(`${waiver.file}:${line}`, { ...waiver, line });
  });

  return { lineWaivers, functionWaivers };
}

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
  const { lineWaivers, functionWaivers } = loadWaivers(waiversPath);
  let hasIssues = false;
  let hasWaivedItems = false;

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
    const actionableFunctions = [];
    const waivedFunctions = [];
    data.functions.details
      .filter((f) => !f.hit)
      .forEach((func) => {
        const waiver = functionWaivers.get(`${relativePath}:${func.name}`);
        if (waiver) {
          hasWaivedItems = true;
          waivedFunctions.push({ name: func.name, ...waiver });
        } else {
          actionableFunctions.push(func);
        }
      });
    const uncoveredBranches = data.branches.details.filter((b) => !b.taken);
    const actionableBranches = [];
    const waivedBranchesByLine = {};

    uncoveredBranches.forEach((branch) => {
      const waiver = lineWaivers.get(`${relativePath}:${branch.line}`);
      if (waiver) {
        hasWaivedItems = true;
        const key = `${branch.line}`;
        if (!waivedBranchesByLine[key]) {
          waivedBranchesByLine[key] = {
            count: 0,
            classification: waiver.classification,
            reason: waiver.reason,
          };
        }
        waivedBranchesByLine[key].count += 1;
      } else {
        actionableBranches.push(branch);
      }
    });

    if (
      actionableFunctions.length > 0 ||
      actionableBranches.length > 0 ||
      waivedFunctions.length > 0 ||
      Object.keys(waivedBranchesByLine).length > 0
    ) {
      if (actionableFunctions.length > 0 || actionableBranches.length > 0) {
        hasIssues = true;
      }
      console.log(`File: ${relativePath}`);

      if (actionableFunctions.length > 0) {
        console.log("  Uncovered Functions:");
        actionableFunctions.forEach((f) => console.log(`    - ${f.name}`));
      }

      if (waivedFunctions.length > 0) {
        console.log("  Waived Functions:");
        waivedFunctions.forEach((f) =>
          console.log(`    - ${f.name} [${f.classification}] - ${f.reason}`)
        );
      }

      if (actionableBranches.length > 0) {
        console.log("  Uncovered Branches:");
        // Group branches by line to avoid spam
        const branchesByLine = {};
        actionableBranches.forEach((b) => {
          branchesByLine[b.line] = (branchesByLine[b.line] || 0) + 1;
        });

        for (const [line, count] of Object.entries(branchesByLine)) {
          console.log(`    - Line ${line}: ${count} branch(es) not taken`);
        }
      }

      if (Object.keys(waivedBranchesByLine).length > 0) {
        console.log("  Waived Branches:");
        for (const [line, details] of Object.entries(waivedBranchesByLine)) {
          console.log(
            `    - Line ${line}: ${details.count} branch(es) waived [${details.classification}] - ${details.reason}`
          );
        }
      }
      console.log("");
    }
  }

  if (!hasIssues) {
    console.log(
      "All contracts have 100% function and branch coverage (or are filtered out)."
    );
  } else if (hasWaivedItems) {
    console.log(
      "Note: waived branches are excluded from actionable regressions.\n"
    );
  }

  if (hasIssues) {
    process.exitCode = 1;
  }
}

// Run if called directly
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  analyzeCoverage();
}

export { analyzeCoverage };
