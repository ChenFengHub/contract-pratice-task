const { ethers } = require("hardhat");
const {deployments, upgrades} = require("hardhat");
// filestring缩写
const fs = require("fs"); 
const path = require("path");
module.exports = async ({getNamedAccounts, deployments, network}) => {
    // npx hardhat node会自动执行deploy目录下脚本，所以本地运行直接过滤...发现这样会导致本地执行部署脚本失败
    // if (network.name === 'localhost' || network.name === 'hardhat') {
    //     console.log("跳过本地网络的完整部署，使用简化版本");
    //     // 在本地网络使用简化版本或跳过
    //     return;
    // }

    const {save} = deployments;
    // 从hardhat.confg.js中获取部署的用户地址
    const {deployer, user1, user2} = await getNamedAccounts();
    console.log("部署：用户地址：", deployer);
    const dynamicToken = await ethers.getContractFactory("DynamicToken");
    // 通过（普通）代理部署合约
    taxCollector = user1; // 使用npx hardhat node --no-deploy 模拟的本地账号 
    // hoodiRouterAddress = "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3";  // 因为hoodi\sepolia可能没有部署Uniswap路由
    zeroRouterAddress = ethers.ZeroAddress;  // 传入零地址，不验证流动性池的兑换的功能
    
    const dynamicTokenProxy = await upgrades.deployProxy(
        dynamicToken, 
        [taxCollector, zeroRouterAddress],  // 初始化参数
        {initializer: "initialize"} // 指定合约执行的初始化方法，名字要统一
    );
    await dynamicTokenProxy.waitForDeployment();
    console.log("代理合约地址：", await dynamicTokenProxy.getAddress());
    const proxyAddress = await dynamicTokenProxy.getAddress();
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log("部署：代理合约地址：", proxyAddress);
    console.log("部署：目标合约地址（实现合约地址）：", implAddress);

    const storePath = path.resolve(__dirname, "./.cache/proxyDynamicToken.json");
    
    fs.writeFileSync(
        storePath,
        JSON.stringify({
            proxyAddress,
            implAddress,
            abi: dynamicToken.interface.format("json"),
        })
    );
    await save("DynamicTokenProxy", {
        abi: dynamicToken.interface.format("json"),
        address: proxyAddress,
        // args: [],
        // log: true,
    });
};
module.exports.tags = ["deployDynamicToken"];

