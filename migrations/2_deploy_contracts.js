const CardOwnership = artifacts.require('CardOwnership')

module.exports = function (deployer) {
  deployer.deploy(CardOwnership)
}
