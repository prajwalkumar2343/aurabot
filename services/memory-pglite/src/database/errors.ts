export class MemoryDatabaseError extends Error {
  readonly cause?: unknown;

  constructor(message: string, options: { cause?: unknown } = {}) {
    super(message);
    this.name = "MemoryDatabaseError";
    this.cause = options.cause;
  }
}

export class MemorySchemaError extends MemoryDatabaseError {
  constructor(message: string, options: { cause?: unknown } = {}) {
    super(message, options);
    this.name = "MemorySchemaError";
  }
}
