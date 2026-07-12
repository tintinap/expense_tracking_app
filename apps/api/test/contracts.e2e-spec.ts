import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsController } from '../src/notifications/notifications.controller';
import { SheetsController } from '../src/sheets/sheets.controller';
import { SyncService } from '../src/sync/sync.service';
import { SheetsService } from '../src/sheets/sheets.service';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Backend Contract Compatibility (regression)', () => {
  describe('NotificationsController aliases', () => {
    let controller: NotificationsController;
    let prisma: { user: { update: jest.Mock } };

    beforeEach(async () => {
      prisma = { user: { update: jest.fn().mockResolvedValue({}) } };
      const module: TestingModule = await Test.createTestingModule({
        controllers: [NotificationsController],
        providers: [{ provide: PrismaService, useValue: prisma }],
      }).compile();

      controller = module.get<NotificationsController>(NotificationsController);
    });

    it('register-token and fcm-token alias write same token', async () => {
      const req = { user: { userId: 'user-1' } };
      const body = { fcmToken: 'abc-token' };

      await controller.registerToken(req, body);
      await controller.registerFcmTokenAlias(req, body);

      expect(prisma.user.update).toHaveBeenNthCalledWith(1, {
        where: { id: 'user-1' },
        data: { fcmToken: 'abc-token' },
      });
      expect(prisma.user.update).toHaveBeenNthCalledWith(2, {
        where: { id: 'user-1' },
        data: { fcmToken: 'abc-token' },
      });
    });

    it('unregister-token and fcm-token delete alias clear token', async () => {
      const req = { user: { userId: 'user-2' } };

      await controller.unregisterToken(req);
      await controller.unregisterFcmTokenAlias(req);

      expect(prisma.user.update).toHaveBeenNthCalledWith(1, {
        where: { id: 'user-2' },
        data: { fcmToken: null },
      });
      expect(prisma.user.update).toHaveBeenNthCalledWith(2, {
        where: { id: 'user-2' },
        data: { fcmToken: null },
      });
    });
  });

  describe('SheetsController compatibility fields and alias', () => {
    let controller: SheetsController;
    let sheetsService: { disconnectSheet: jest.Mock; setupSheet: jest.Mock };
    let prisma: { user: { findUnique: jest.Mock } };

    beforeEach(async () => {
      sheetsService = {
        disconnectSheet: jest.fn().mockResolvedValue(undefined),
        setupSheet: jest.fn(),
      };
      prisma = {
        user: {
          findUnique: jest.fn().mockResolvedValue({
            sheetsEnabled: true,
            sheetsSpreadsheetId: 'sheet-123',
          }),
        },
      };

      const module: TestingModule = await Test.createTestingModule({
        controllers: [SheetsController],
        providers: [
          { provide: SheetsService, useValue: sheetsService },
          { provide: PrismaService, useValue: prisma },
        ],
      }).compile();

      controller = module.get<SheetsController>(SheetsController);
    });

    it('status returns both connected and enabled for clients', async () => {
      const result = await controller.status({ user: { userId: 'user-1' } });
      expect(result).toEqual({
        connected: true,
        enabled: true,
        spreadsheetId: 'sheet-123',
      });
    });

    it('post disconnect alias delegates to disconnect behavior', async () => {
      const req = { user: { userId: 'user-1' } };
      await expect(controller.disconnectAlias(req)).resolves.toEqual({ success: true });
      expect(sheetsService.disconnectSheet).toHaveBeenCalledWith('user-1');
    });
  });

  describe('SyncService response compatibility', () => {
    let service: SyncService;
    let repository: { pullRecords: jest.Mock };

    beforeEach(() => {
      repository = {
        pullRecords: jest.fn().mockResolvedValue({
          transactions: [{ id: 't1' }],
          categories: [{ id: 'c1' }],
          budgets: [{ id: 'b1' }],
        }),
      };
      service = new SyncService(repository as any, {
        evaluateUserBudgets: jest.fn().mockResolvedValue(undefined),
      } as any);
    });

    it('processPush includes synced alias with accepted count', async () => {
      const result = await service.processPush('user-1', []);
      expect(result.accepted).toBe(0);
      expect(result.synced).toBe(0);
      expect(result.conflicts).toEqual([]);
      expect(typeof result.serverTimestamp).toBe('string');
    });

    it('processPull returns flat records and nested changes shape', async () => {
      const result = await service.processPull('user-1', new Date('2026-01-01T00:00:00.000Z'));
      expect(repository.pullRecords).toHaveBeenCalled();
      expect(result.transactions).toEqual([{ id: 't1' }]);
      expect(result.categories).toEqual([{ id: 'c1' }]);
      expect(result.budgets).toEqual([{ id: 'b1' }]);
      expect(result.changes).toEqual({
        transactions: [{ id: 't1' }],
        categories: [{ id: 'c1' }],
        budgets: [{ id: 'b1' }],
      });
      expect(result.conflicts).toEqual([]);
      expect(typeof result.serverTimestamp).toBe('string');
    });
  });
});
