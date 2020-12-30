const CardMinting = artifacts.require('CardMinting')

module.exports = function (deployer) {
  deployer.deploy(CardMinting)
}
