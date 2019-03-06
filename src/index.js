import axios from 'axios'

export const client = (baseURL) => {
  const axiosClient = axios.create({ baseURL })
  return {
    active: () => axiosClient.get('/'),
    choose: (experiment, metadata={}) => axiosClient.post(`/${experiment}`, { metadata }),
    convert: (experiment, checkpoint=undefined, metadata={}) => axiosClient.put(`/${experiment}`, { checkpoint, metadata })
  }
}
