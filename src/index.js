import axios from 'axios'

export const client = (axiosConfig) => {
  if (typeof axiosConfig == "string")
    axiosConfig = { baseURL: axiosConfig }

  const axiosClient = axios.create(axiosConfig)
  return {
    active: () => axiosClient.get('/'),
    choose: (experiment, metadata={}) => axiosClient.post(`/${experiment}`, { metadata }),
    convert: (experiment, checkpoint=undefined, metadata={}) => axiosClient.put(`/${experiment}`, { checkpoint, metadata })
  }
}
