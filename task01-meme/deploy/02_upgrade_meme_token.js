const { ethers} = require("hardhat");
const fs = require("fs"); 
const path = require("path");
module.exports = async ({getNamedAccounts, deployments}) => { 
    const {save} = deployments;
    const {deployer} = await getNamedAccounts();
    console.log("升级：用户地址：", deployer);
    // 设置 ./cache/proxyDynamicToken.json文件
    const storePath = path.resolve(__dirname, "./.cache/proxyDynamicToken.json");
    const storeData = fs.readFileSync(storePath, "utf-8");
    const { proxyAddress, implAddress, abi} = JSON.parse(storeData);
    // 升级版本的合约(还是使用之前的合约)
    const nftAuctionV2 = await ethers.getContractFactory("DynamicTokenV2");
    // 升级代理合约
    const nftAuctionV2Proxy = await upgrades.upgradeProxy(proxyAddress, nftAuctionV2);
    await nftAuctionV2Proxy.waitForDeployment();
    const proxyAddressV2 = await nftAuctionV2Proxy.getAddress();
    const implAddressV2 = await upgrades.erc1967.getImplementationAddress(proxyAddressV2);
    console.log("升级：代理合约地址：", proxyAddressV2);
    console.log("升级：目标合约地址（实现合约地址）：", implAddressV2);
    // 保存代理合约地址
    // fs.writeFileSync(
    //     storePath,
    //     JSON.stringify({
    //         proxyAddress: proxyAddressV2,
    //         implAddress,
    //         abi
    //     })
    // );
    await save("DynamicTokenProxyV2", {
        address: proxyAddressV2,
        abi,
    });
}

module.exports.tags = ["upgradeDynamicToken"];