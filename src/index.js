import axios from 'axios'

const mergeConfig = (config) => {
  if (config == undefined)
    return config

  if (config.transformRequest)
    config.transformRequest = [
      ...config.transformRequest,
      ...axios.defaults.transformRequest
    ]

  if (config.transformResponse)
    config.transformResponse = [
      ...axios.defaults.transformResponse,
      ...config.transformResponse
    ]

  return config
}

export const client = (axiosConfig) => {
  if (typeof axiosConfig == "string")
    axiosConfig = { baseURL: axiosConfig }

  const axiosClient = axios.create(mergeConfig(axiosConfig))

  return {
    active: (requestConfig=undefined) =>
      axiosClient.get('/', mergeConfig(requestConfig)),

    choose: (experiment, metadata={}, requestConfig=undefined) =>
      axiosClient.post(`/${experiment}`, { metadata }, mergeConfig(requestConfig)),

    convert: (experiment, checkpoint=undefined, metadata={}, requestConfig=undefined) =>
      axiosClient.put(`/${experiment}`, { checkpoint, metadata }, mergeConfig(requestConfig)),

    run: (experiment, metadata={}, callbacks={}, requestConfig=undefined) => {
      axiosClient.post(`/${experiment}`, { metadata }, mergeConfig(requestConfig))
        .then(({ data, ...request }) => {
          if (callbacks[data.variant])
            callbacks[data.variant](data)
        })
    },
  }
}
