import { execFileSync } from "child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const EVM_ROOT = join(__dirname, "..");
const SNAPSHOT_DIR = join(EVM_ROOT, "storage-layout");

const UPGRADEABLE_CONTRACTS = [
  "PartnerManager",
  "RegistryRouter",
  "RoboshareTokens",
  "Treasury",
  "Marketplace",
  "VehicleRegistry",
];

function ensureSnapshotDir() {
  if (!existsSync(SNAPSHOT_DIR)) {
    mkdirSync(SNAPSHOT_DIR, { recursive: true });
  }
}

function ensureArtifacts() {
  execFileSync("forge", ["clean"], {
    cwd: EVM_ROOT,
    encoding: "utf8",
    stdio: ["ignore", "inherit", "inherit"],
  });

  execFileSync("forge", ["build"], {
    cwd: EVM_ROOT,
    encoding: "utf8",
    stdio: ["ignore", "inherit", "inherit"],
  });
}

function readRawStorageLayout(contractName) {
  const stdout = execFileSync(
    "forge",
    ["inspect", contractName, "storage-layout", "--json"],
    {
      cwd: EVM_ROOT,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "inherit"],
    }
  );

  return JSON.parse(stdout);
}

function normalizeStorageLayout(contractName) {
  const raw = readRawStorageLayout(contractName);
  const typesById = raw.types ?? {};
  const seen = new Set();

  function resolveTypeLabel(typeId) {
    return typesById[typeId]?.label ?? typeId;
  }

  function visitType(typeId) {
    const typeMeta = typesById[typeId];
    if (!typeMeta) {
      return null;
    }

    const typeLabel = typeMeta.label;
    if (seen.has(typeLabel)) {
      return null;
    }
    seen.add(typeLabel);

    const normalized = {
      label: typeLabel,
      encoding: typeMeta.encoding,
      numberOfBytes: typeMeta.numberOfBytes,
    };

    if (typeMeta.key) {
      normalized.key = resolveTypeLabel(typeMeta.key);
      visitType(typeMeta.key);
    }

    if (typeMeta.value) {
      normalized.value = resolveTypeLabel(typeMeta.value);
      visitType(typeMeta.value);
    }

    if (typeMeta.base) {
      normalized.base = resolveTypeLabel(typeMeta.base);
      visitType(typeMeta.base);
    }

    if (typeMeta.members) {
      normalized.members = typeMeta.members.map((member) => {
        visitType(member.type);
        return {
          label: member.label,
          slot: member.slot,
          offset: member.offset,
          type: resolveTypeLabel(member.type),
        };
      });
    }

    return normalized;
  }

  const normalizedTypes = [];
  for (const item of raw.storage ?? []) {
    const maybeType = visitType(item.type);
    if (maybeType) {
      normalizedTypes.push(maybeType);
    }
  }

  normalizedTypes.sort((a, b) => a.label.localeCompare(b.label));

  return {
    contract: contractName,
    source: raw.storage?.[0]?.contract ?? null,
    storage: (raw.storage ?? []).map((item) => ({
      label: item.label,
      slot: item.slot,
      offset: item.offset,
      type: resolveTypeLabel(item.type),
    })),
    types: normalizedTypes,
  };
}

function snapshotPath(contractName) {
  return join(SNAPSHOT_DIR, `${contractName}.json`);
}

function writeSnapshot(contractName) {
  const normalized = normalizeStorageLayout(contractName);
  writeFileSync(
    snapshotPath(contractName),
    `${JSON.stringify(normalized, null, 2)}\n`
  );
  console.log(`Wrote storage layout snapshot for ${contractName}`);
}

function diffContract(contractName) {
  const normalized = normalizeStorageLayout(contractName);
  const path = snapshotPath(contractName);

  if (!existsSync(path)) {
    return `Missing snapshot for ${contractName}: ${path}`;
  }

  const expected = JSON.parse(readFileSync(path, "utf8"));
  if (JSON.stringify(expected) !== JSON.stringify(normalized)) {
    return `Storage layout mismatch for ${contractName}. Run \`yarn workspace evm storage:layout:snapshot\` after reviewing the change.`;
  }

  return null;
}

function printUsage() {
  console.log("Usage:");
  console.log("  yarn workspace evm storage:layout:snapshot");
  console.log("  yarn workspace evm storage:layout:check");
}

function main() {
  const command = process.argv[2];
  ensureSnapshotDir();

  if (command === "snapshot") {
    ensureArtifacts();
    UPGRADEABLE_CONTRACTS.forEach(writeSnapshot);
    return;
  }

  if (command === "check") {
    ensureArtifacts();
    const failures = UPGRADEABLE_CONTRACTS.map(diffContract).filter(Boolean);
    if (failures.length > 0) {
      console.error(failures.join("\n"));
      process.exit(1);
    }
    console.log(
      "Storage layout snapshots match all tracked upgradeable contracts."
    );
    return;
  }

  printUsage();
  process.exit(1);
}

main();
