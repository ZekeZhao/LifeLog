import { http } from '@kit.NetworkKit'

export class HarmonyHeaders {
  apikey: string = ''
  Authorization: string = ''
  contentType: string = ''
  prefer: string = ''
}

class RequestHeaderMap {
  apikey: string = ''
  Authorization: string = ''
  contentType?: string
  Prefer?: string
}

class HarmonyRequestOptions {
  method: http.RequestMethod = http.RequestMethod.GET
  header: RequestHeaderMap = new RequestHeaderMap()
  connectTimeout: number = 10000
  readTimeout: number = 30000
  expectDataType: http.HttpDataType = http.HttpDataType.STRING
  extraData: string = ''
}

export class HarmonyHttpClient {
  async get(url: string, headers: HarmonyHeaders): Promise<string> {
    const options = this.createOptions(http.RequestMethod.GET, headers, '')
    return await this.send(url, options)
  }

  async postJson(url: string, headers: HarmonyHeaders, body: string): Promise<string> {
    const options = this.createOptions(http.RequestMethod.POST, headers, body)
    return await this.send(url, options)
  }

  async postForm(url: string, headers: HarmonyHeaders, body: string): Promise<string> {
    const options = this.createOptions(http.RequestMethod.POST, headers, body)
    return await this.send(url, options)
  }

  private createOptions(method: http.RequestMethod, headers: HarmonyHeaders, body: string): HarmonyRequestOptions {
    const options = new HarmonyRequestOptions()
    options.method = method
    options.header = this.createHeaderMap(headers)
    options.extraData = body
    return options
  }

  private createHeaderMap(headers: HarmonyHeaders): RequestHeaderMap {
    const headerMap = new RequestHeaderMap()
    headerMap.apikey = headers.apikey
    headerMap.Authorization = headers.Authorization
    if (headers.contentType.length > 0) {
      headerMap.contentType = headers.contentType
    }
    if (headers.prefer.length > 0) {
      headerMap.Prefer = headers.prefer
    }
    return headerMap
  }

  private async send(url: string, options: HarmonyRequestOptions): Promise<string> {
    const request = http.createHttp()
    try {
      const response = await request.request(url, options)
      const statusCode = Number(response.responseCode)
      const resultText = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result)

      if (statusCode < 200 || statusCode >= 300) {
        throw new Error(`HTTP ${statusCode}: ${resultText}`)
      }
      return resultText
    } finally {
      request.destroy()
    }
  }
}
