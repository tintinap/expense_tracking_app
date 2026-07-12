import { Injectable, Logger } from '@nestjs/common';
import { SyncRepository } from './sync.repository';
import { BudgetAlertsService } from '../budgets/budget-alerts.service';
import { SheetsProcessor } from '../sheets/sheets.processor';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    private readonly repository: SyncRepository,
    private readonly budgetAlerts: BudgetAlertsService,
    private readonly sheetsProcessor: SheetsProcessor,
  ) {}

  /**
   * Process push from mobile: handle insert/update/delete for each record.
   * Uses last-write-wins conflict resolution based on updatedAt timestamp.
   */
  async processPush(
    userId: string,
    records: Array<{
      recordType: string;
      recordId: string;
      operation: string;
      payload: any;
    }>,
  ) {
    let accepted = 0;
    const conflicts: Array<{ recordType: string; recordId: string; error: string }> = [];

    for (const record of records) {
      try {
        switch (record.recordType) {
          case 'transaction':
            await this.syncTransaction(userId, record);
            break;
          case 'category':
            await this.syncCategory(userId, record);
            break;
          case 'budget':
            await this.syncBudget(userId, record);
            break;
          default:
            this.logger.warn(`Unknown record type: ${record.recordType}`);
            continue;
        }
        accepted++;
      } catch (error) {
        this.logger.error(
          `Sync error for ${record.recordType}/${record.recordId}: ${error.message}`,
        );
        conflicts.push({
          recordType: record.recordType,
          recordId: record.recordId,
          error: error.message,
        });
      }
    }

    // Evaluate budgets after successfully processing a batch
    if (accepted > 0) {
      await this.budgetAlerts.evaluateUserBudgets(userId).catch((err) => {
        this.logger.error(`Failed to evaluate budgets: ${err.message}`);
      });
    }

    return {
      accepted,
      synced: accepted,
      conflicts,
      serverTimestamp: new Date().toISOString(),
    };
  }

  /**
   * Process pull: return all records updated after the given timestamp.
   */
  async processPull(userId: string, lastSync: Date) {
    const data = await this.repository.pullRecords(userId, lastSync);

    return {
      ...data,
      changes: data,
      serverTimestamp: new Date().toISOString(),
      conflicts: [],
    };
  }

  private getBalanceDelta(transactionType: string, amount: number): number {
    switch (transactionType) {
      case 'expense':
      case 'currency_exchange_out':
        return -amount;
      case 'currency_income':
      case 'currency_exchange_in':
        return amount;
      default:
        return 0;
    }
  }

  private async syncTransaction(
    userId: string,
    record: { recordId: string; operation: string; payload: any },
  ) {
    const { recordId, operation, payload } = record;

    switch (operation) {
      case 'insert': {
        // UUID deduplication — check if record already exists
        const existing = await this.repository.findTransactionById(recordId);
        if (existing) return; // Already synced

        await this.repository.createTransaction({
          id: recordId,
          userId,
          transactionType: payload.transactionType,
          amountBase: payload.amountBase,
          originalAmount: payload.originalAmount,
          originalCurrency: payload.originalCurrency,
          exchangeRate: payload.exchangeRate,
          rateDate: new Date(payload.rateDate),
          rateEstimated: payload.rateEstimated || false,
          rateSource: payload.rateSource || 'frankfurter',
          exchangeEventId: payload.exchangeEventId || null,
          categoryId: payload.categoryId || null,
          note: payload.note || null,
          sourceLabel: payload.sourceLabel || null,
          transactionDate: new Date(payload.transactionDate),
          isRecurring: payload.isRecurring || false,
          recurrenceType: payload.recurrenceType || null,
        });

        const delta = this.getBalanceDelta(payload.transactionType, Number(payload.originalAmount));
        if (delta !== 0) {
          await this.repository.upsertCurrencyBalance(userId, payload.originalCurrency, delta);
        }
        await this.enqueueSheetWrite(userId, 'append', payload);
        break;
      }

      case 'update': {
        // Last-write-wins: compare updatedAt
        const existing = await this.repository.findTransactionById(recordId);

        if (existing) {
          const clientUpdated = new Date(payload.updatedAt);
          if (clientUpdated > existing.updatedAt) {
            await this.repository.updateTransaction(recordId, {
              amountBase: payload.amountBase,
              originalAmount: payload.originalAmount,
              originalCurrency: payload.originalCurrency,
              exchangeRate: payload.exchangeRate,
              rateDate: new Date(payload.rateDate),
              rateEstimated: payload.rateEstimated || false,
              rateSource: payload.rateSource || 'frankfurter',
              categoryId: payload.categoryId || null,
              note: payload.note || null,
              transactionDate: new Date(payload.transactionDate),
            });

            // Reverse old balance impact
            const oldDelta = this.getBalanceDelta(existing.transactionType, Number(existing.originalAmount));
            if (oldDelta !== 0) {
              await this.repository.upsertCurrencyBalance(userId, existing.originalCurrency, -oldDelta);
            }

            // Apply new balance impact
            const newTxType = payload.transactionType || existing.transactionType;
            const newAmount = payload.originalAmount !== undefined ? payload.originalAmount : existing.originalAmount;
            const newCurrency = payload.originalCurrency || existing.originalCurrency;
            
            const newDelta = this.getBalanceDelta(newTxType, Number(newAmount));
            if (newDelta !== 0) {
              await this.repository.upsertCurrencyBalance(userId, newCurrency, newDelta);
            }
            await this.enqueueSheetWrite(userId, 'update', payload);
          } else {
            // Server version is newer — log conflict
            await this.repository.logConflict({
              userId,
              recordType: 'transaction',
              recordId,
              winningVersion: existing as any,
              losingVersion: payload,
            });
          }
        }
        break;
      }

      case 'delete': {
        const existing = await this.repository.findTransactionById(recordId);
        if (existing && !existing.deletedAt) {
          const oldDelta = this.getBalanceDelta(existing.transactionType, Number(existing.originalAmount));
          if (oldDelta !== 0) {
            await this.repository.upsertCurrencyBalance(userId, existing.originalCurrency, -oldDelta);
          }
        }
        await this.repository.softDeleteTransaction(recordId);
        await this.enqueueSheetWrite(userId, 'delete', { uuid: recordId });
        break;
      }
    }
  }

  private async enqueueSheetWrite(
    userId: string,
    operation: 'append' | 'update' | 'delete',
    payload: any,
  ) {
    const user = await this.repository.getUserSheetInfo(userId);
    if (!user?.sheetsEnabled || !user.sheetsSpreadsheetId) {
      return;
    }

    this.sheetsProcessor.enqueue({
      userId,
      spreadsheetId: user.sheetsSpreadsheetId,
      operation,
      payload,
    });
  }

  private async syncCategory(
    userId: string,
    record: { recordId: string; operation: string; payload: any },
  ) {
    const { recordId, operation, payload } = record;

    switch (operation) {
      case 'insert': {
        const existing = await this.repository.findCategoryById(recordId);
        if (existing) return;

        if (payload.parentId) {
          const parent = await this.repository.findCategoryById(payload.parentId);
          if (!parent) throw new Error(`Invalid parentId: Parent category not found`);
          if (parent.parentId) throw new Error(`Invalid parentId: Maximum category depth exceeded (1 level allowed).`);
        }

        await this.repository.createCategory({
          id: recordId,
          userId,
          name: payload.name,
          colourHex: payload.colourHex,
          iconCodePoint: payload.iconCodePoint ?? 0,
          isDefault: payload.isDefault || false,
          isHidden: payload.isHidden || false,
          sortOrder: payload.sortOrder || 0,
          parentId: payload.parentId || null,
        });
        break;
      }

      case 'update': {
        if (payload.parentId) {
          const parent = await this.repository.findCategoryById(payload.parentId);
          if (!parent) throw new Error(`Invalid parentId: Parent category not found`);
          if (parent.parentId) throw new Error(`Invalid parentId: Maximum category depth exceeded (1 level allowed).`);
        }

        await this.repository.updateCategory(recordId, {
          name: payload.name,
          colourHex: payload.colourHex,
          ...(payload.iconCodePoint !== undefined && { iconCodePoint: payload.iconCodePoint }),
          isHidden: payload.isHidden,
          parentId: payload.parentId,
        });
        break;
      }

      case 'delete': {
        await this.repository.deleteCategory(recordId);
        break;
      }
    }
  }

  private async syncBudget(
    userId: string,
    record: { recordId: string; operation: string; payload: any },
  ) {
    const { recordId, operation, payload } = record;

    switch (operation) {
      case 'insert': {
        const existing = await this.repository.findBudgetById(recordId);
        if (existing) return;

        await this.repository.createBudget({
          id: recordId,
          userId,
          name: payload.name ?? null,
          scopeType: payload.scopeType,
          categoryIds: payload.categoryIds ?? null,
          currency: payload.currency,
          amountBase: payload.amountBase,
          periodType: payload.periodType,
          isRecurring: payload.isRecurring ?? true,
          startDate: new Date(payload.startDate),
          endDate: payload.endDate ? new Date(payload.endDate) : null,
          isActive: payload.isActive ?? true,
        });
        break;
      }

      case 'update': {
        await this.repository.updateBudget(recordId, {
          name: payload.name ?? null,
          scopeType: payload.scopeType,
          categoryIds: payload.categoryIds ?? null,
          currency: payload.currency,
          amountBase: payload.amountBase,
          periodType: payload.periodType,
          isRecurring: payload.isRecurring ?? true,
          startDate: new Date(payload.startDate),
          endDate: payload.endDate ? new Date(payload.endDate) : null,
          isActive: payload.isActive ?? true,
          notified75: payload.notified75 ?? false,
          notified90: payload.notified90 ?? false,
          notified100: payload.notified100 ?? false,
        });
        break;
      }

      case 'delete': {
        await this.repository.deleteBudget(recordId);
        break;
      }
    }
  }
}
