// Shared browser-safe capacity formatter.
// Keep this as a script (without imports) because the renderer modules are
// loaded directly by the HTML pages rather than bundled together.

type CapacityFormatter = (bytes: number) => string;

const formatCapacity: CapacityFormatter = (bytes: number): string => {
  const value = Number.isFinite(bytes) ? Math.max(0, bytes) : 0;
  const units = [
    { size: 1024 ** 5, suffix: 'PB', decimals: 2 },
    { size: 1024 ** 4, suffix: 'TB', decimals: 2 },
    { size: 1024 ** 3, suffix: 'GB', decimals: 2 },
    { size: 1024 ** 2, suffix: 'MB', decimals: 1 },
    { size: 1024, suffix: 'KB', decimals: 1 }
  ];

  for (const unit of units) {
    if (value >= unit.size) return `${(value / unit.size).toFixed(unit.decimals)} ${unit.suffix}`;
  }
  return `${Math.floor(value)} B`;
};

(globalThis as any).NigateFormatCapacity = formatCapacity;
