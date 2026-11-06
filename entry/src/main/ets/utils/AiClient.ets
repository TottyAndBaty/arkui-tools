import { http } from '@kit.NetworkKit';

/**
 * Calls the Node service that turns a natural language prompt into a component tree.
 * The endpoint is configurable because the emulator reaches the host machine through
 * 10.0.2.2 while a real device needs the LAN address of the machine running `server`.
 */
export class AiClient {
  static readonly DEFAULT_ENDPOINT: string = 'http://10.0.2.2:3000/api/generate';

  static async generate(endpoint: string, prompt: string): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(endpoint, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify({ prompt: prompt }),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 60000
      });
      if (response.responseCode !== 200) {
        throw new Error(`服务返回 ${response.responseCode}`);
      }
      const body = response.result as string;
      if (typeof body !== 'string' || body.length === 0) {
        throw new Error('服务未返回内容');
      }
      return body;
    } finally {
      request.destroy();
    }
  }
}
