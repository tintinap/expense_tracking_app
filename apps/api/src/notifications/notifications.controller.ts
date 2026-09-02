import { Controller, Post, Delete, Body, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly prisma: PrismaService) {}

  private async persistFcmToken(userId: string, fcmToken: string | null) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken },
    });
    return { success: true };
  }

  @Post('register-token')
  @ApiOperation({ summary: 'Register FCM token for push notifications' })
  async registerToken(@Req() req, @Body() body: { fcmToken: string }) {
    return this.persistFcmToken(req.user.userId, body.fcmToken);
  }

  @Post('fcm-token')
  @ApiOperation({ summary: 'Register FCM token (compat alias)' })
  async registerFcmTokenAlias(@Req() req, @Body() body: { fcmToken: string }) {
    return this.persistFcmToken(req.user.userId, body.fcmToken);
  }

  @Delete('unregister-token')
  @ApiOperation({ summary: 'Remove FCM token' })
  async unregisterToken(@Req() req) {
    return this.persistFcmToken(req.user.userId, null);
  }

  @Delete('fcm-token')
  @ApiOperation({ summary: 'Remove FCM token (compat alias)' })
  async unregisterFcmTokenAlias(@Req() req) {
    return this.persistFcmToken(req.user.userId, null);
  }
}
