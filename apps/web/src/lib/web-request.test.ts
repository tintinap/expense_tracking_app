import { describe, expect, it, vi, beforeEach } from 'vitest';
import { request } from './web-request';

describe('web-request', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.stubGlobal('localStorage', {
      getItem: vi.fn((key: string) => (key === 'accessToken' ? 'token-123' : null)),
    });
  });

  it('adds auth header when token exists', async () => {
    const fetchMock = vi.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ ok: true }), { status: 200 }),
    );

    await request('/health');

    expect(fetchMock).toHaveBeenCalled();
    const [, options] = fetchMock.mock.calls[0];
    expect((options?.headers as Record<string, string>).Authorization).toBe('Bearer token-123');
  });
});
