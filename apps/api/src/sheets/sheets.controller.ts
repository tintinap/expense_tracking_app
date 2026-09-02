import { Controller, Post, Delete, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { SheetsService } from './sheets.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';

@ApiTags('Sheets')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sheets')
export class SheetsController {
  constructor(
    private readonly sheetsService: SheetsService,
    private readonly prisma: PrismaService
  ) {}

  @Post('setup')
  @ApiOperation({ summary: 'Setup Google Sheet sync for user' })
  async setup(@Req() req) {
    const userId = req.user.userId;
    return this.sheetsService.setupSheet(userId);
  }

  @Delete('disconnect')
  @ApiOperation({ summary: 'Disconnect Google Sheet sync for user' })
  async disconnect(@Req() req) {
    const userId = req.user.userId;
    await this.sheetsService.disconnectSheet(userId);
    return { success: true };
  }

  @Post('disconnect')
  @ApiOperation({ summary: 'Disconnect Google Sheet sync for user (compat alias)' })
  async disconnectAlias(@Req() req) {
    return this.disconnect(req);
  }

  @Get('status')
  @ApiOperation({ summary: 'Get Google Sheet sync status' })
  async status(@Req() req) {
    const userId = req.user.userId;
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { sheetsEnabled: true, sheetsSpreadsheetId: true }
    });
    
    const connected = user?.sheetsEnabled ?? false;
    const spreadsheetId = user?.sheetsSpreadsheetId ?? null;
    return {
      connected,
      enabled: connected,
      spreadsheetId,
    };
  }
}
