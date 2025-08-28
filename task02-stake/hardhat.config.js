require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-deploy");
require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  // settings: {
  //   viaIR: true,  // 启用 IR 编译管道；否则TaxTier[] internal taxTiers 这里无法支持直接将内存中的数组复制到storage中
  //   optimizer: {
  //     enabled: true,
  //     runs: 200
  //   }
  // },
  namedAccounts: {
    deployer: 0,
    user1: 1,
    user2: 2,
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,  // 从sepolia中随便选个可用的地址，从https://developer.metamask.io/中获取
      accounts: [process.env.PRIVATE_KEY]    // 账户私钥，正常是严禁保存泄露的
    },
    hoodi: {
      url: `https://hoodi.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [
        process.env.PRIVATE_KEY,
        process.env.PRIVATE_KEY_2,
        process.env.PRIVATE_KEY_3
      ]
    },
  },

};