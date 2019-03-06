const path = require('path')

// TODO create another config to export for modern browsers
module.exports = {
  entry: './src/index.js',
  output: {
    path: path.resolve(__dirname, 'app/assets/javascripts/'),
    filename: 'trailguide.js',
    library: 'TrailGuide',
    libraryTarget: 'this'
  },
  module: {
    rules: [
      {
        test: /\.(js|jsx)$/,
        exclude: /node_modules/,
        use: ['babel-loader']
      }
    ]
  },
  resolve: {
    extensions: ['*', '.js', '.jsx']
  },
  externals: {
    'react': 'commonjs react' 
  }
}
