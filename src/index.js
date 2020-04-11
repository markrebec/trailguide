import axios from 'axios'

export const client = (axiosConfig) => {
  if (typeof axiosConfig == "string")
    axiosConfig = { baseURL: axiosConfig }

  if (axiosConfig.transformRequest)
    axiosConfig.transformRequest = [
      ...axiosConfig.transformRequest,
      ...axios.defaults.transformRequest
    ]

  if (axiosConfig.transformResponse)
    axiosConfig.transformResponse = [
      ...axios.defaults.transformResponse,
      ...axiosConfig.transformResponse
    ]

  const axiosClient = axios.create(axiosConfig)

  return {
    active: (requestConfig=undefined) =>
      axiosClient.get('/', requestConfig),

    choose: (experiment, metadata={}, requestConfig=undefined) =>
      axiosClient.post(`/${experiment}`, { metadata }, requestConfig),

    convert: (experiment, checkpoint=undefined, metadata={}, requestConfig=undefined) =>
      axiosClient.put(`/${experiment}`, { checkpoint, metadata }, requestConfig),
  }
}
