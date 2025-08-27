const { ethers } = require("hardhat");
const {deployments, upgrades} = require("hardhat");
module.exports = async ({getNamedAccounts, deployments}) => {
    console.log("deploy beigin");
    const {save} = deployments;
    // 从hardhat.confg.js中获取部署的用户地址
    const {deployer} = await getNamedAccounts();
    console.log("部署的用户地址：", deployer);
    const nftAuction = await ethers.getContractFactory("NftAuction");
    // 通过（普通）代理部署合约
    const nftAuctionProxy = await upgrades.deployProxy(
        nftAuction, 
        [], 
        {initializer: "initialize"} // 指定合约执行的初始化方法，名字要统一
    );
    await nftAuctionProxy.waitForDeployment();
    console.log("代理合约地址：", await nftAuctionProxy.getAddress());
    
};
module.exports.tags = ["deployNftAuction"];

