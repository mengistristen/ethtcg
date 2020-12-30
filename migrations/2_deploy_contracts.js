const GetCode = artifacts.require('GetCode')
const BytesLibrary = artifacts.require('BytesLibrary')
const CardOwnership = artifacts.require('CardOwnership')

module.exports = function (deployer) {
  deployer.deploy(GetCode)
  deployer.deploy(BytesLibrary)
  deployer.link(GetCode, CardOwnership)
  deployer.link(BytesLibrary, CardOwnership)
  deployer.deploy(CardOwnership)
}
