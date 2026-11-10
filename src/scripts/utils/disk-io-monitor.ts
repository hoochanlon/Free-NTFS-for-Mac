import { spawn, type ChildProcess } from 'child_process';

export type DiskIoListener = (active: boolean) => void;

const RESTART_DELAY_MS = 2000;
const ACTIVE_TPS = 1;
const ACTIVE_MBS = 0.01;

function sameDisks(a: string[], b: string[]): boolean {
  return a.length === b.length && a.every((disk, index) => disk === b[index]);
}

function parseRateLine(line: string): Array<{ tps: number; mbs: number }> | null {
  const trimmed = line.trim();
  if (!trimmed || /[a-zA-Z]/.test(trimmed)) {
    return null;
  }

  const nums = trimmed.split(/\s+/).map(Number);
  if (nums.length < 3 || nums.some((n) => Number.isNaN(n))) {
    return null;
  }

  const groups: Array<{ tps: number; mbs: number }> = [];
  for (let i = 0; i + 2 < nums.length; i += 3) {
    groups.push({ tps: nums[i + 1], mbs: nums[i + 2] });
  }
  return groups.length > 0 ? groups : null;
}

function lineHasActivity(line: string): boolean | null {
  const groups = parseRateLine(line);
  if (!groups) {
    return null;
  }
  return groups.some((group) => group.tps >= ACTIVE_TPS || group.mbs >= ACTIVE_MBS);
}

class DiskIoMonitor {
  private proc: ChildProcess | null = null;
  private disks: string[] = [];
  private listener: DiskIoListener | null = null;
  private buffer = '';
  private skippedFirstSample = false;
  private restartTimer: NodeJS.Timeout | null = null;
  private running = false;
  private generation = 0;

  start(disks: string[], listener: DiskIoListener): void {
    this.listener = listener;
    this.running = true;
    this.setDisks(disks);
  }

  setDisks(disks: string[]): void {
    const next = [...new Set(disks)].sort();
    if (sameDisks(next, this.disks) && this.proc && !this.proc.killed) {
      return;
    }
    this.disks = next;
    if (!this.running) {
      return;
    }
    this.spawnIostat();
  }

  stop(): void {
    this.running = false;
    this.listener = null;
    this.disks = [];
    this.kill();
  }

  private spawnIostat(): void {
    this.kill();
    this.buffer = '';
    this.skippedFirstSample = false;

    if (this.disks.length === 0) {
      this.listener?.(false);
      return;
    }

    const generation = ++this.generation;
    this.proc = spawn(
      'iostat',
      ['-d', '-w', '1', '-n', String(this.disks.length), ...this.disks],
      { stdio: ['ignore', 'pipe', 'pipe'] }
    );

    this.proc.stdout?.on('data', (chunk: Buffer) => {
      this.buffer += chunk.toString('utf8');
      const lines = this.buffer.split('\n');
      this.buffer = lines.pop() ?? '';
      for (const line of lines) {
        this.onLine(line);
      }
    });

    this.proc.stderr?.on('data', (chunk: Buffer) => {
      const text = chunk.toString('utf8').trim();
      if (text) {
        console.warn('[DiskIo] iostat stderr:', text);
      }
    });

    this.proc.on('error', (error) => {
      console.error('[DiskIo] iostat 启动失败:', error);
      if (generation === this.generation) {
        this.proc = null;
        this.listener?.(false);
      }
    });

    this.proc.on('close', (code) => {
      if (generation !== this.generation) {
        return;
      }
      this.proc = null;
      if (!this.running || this.disks.length === 0) {
        return;
      }
      console.warn(`[DiskIo] iostat 退出 (${code})，稍后重试`);
      this.scheduleRestart();
    });
  }

  private onLine(line: string): void {
    const active = lineHasActivity(line);
    if (active === null) {
      return;
    }
    if (!this.skippedFirstSample) {
      this.skippedFirstSample = true;
      return;
    }
    this.listener?.(active);
  }

  private scheduleRestart(): void {
    if (this.restartTimer) {
      return;
    }
    this.restartTimer = setTimeout(() => {
      this.restartTimer = null;
      if (this.running && this.disks.length > 0) {
        this.spawnIostat();
      }
    }, RESTART_DELAY_MS);
  }

  private kill(): void {
    this.generation += 1;
    if (this.restartTimer) {
      clearTimeout(this.restartTimer);
      this.restartTimer = null;
    }
    if (this.proc && !this.proc.killed) {
      try {
        this.proc.kill();
      } catch (error) {
        console.error('[DiskIo] 停止 iostat 失败:', error);
      }
    }
    this.proc = null;
  }
}

export const diskIoMonitor = new DiskIoMonitor();
