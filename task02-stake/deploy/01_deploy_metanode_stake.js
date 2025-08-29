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
    const {owner} = await getNamedAccounts();
    console.log("部署：用户地址：", owner);


    const metaNodeStake = await ethers.getContractFactory("MetaNodeStake");
    const metaNodePerBlock =  10;

    const MetaNode = await ethers.getContractFactory("MetaNodeToken");
    const metaNode = await MetaNode.deploy();
    await metaNode.waitForDeployment();
    const metaNodeAddress = await metaNode.getAddress();
    console.log("MetaNode代币地址：", metaNodeAddress);
    
    const metaNodeStakeProxy = await upgrades.deployProxy(
        metaNodeStake, 
        [metaNodePerBlock, metaNodeAddress],  // 初始化参数
        {initializer: "initialize"} // 指定合约执行的初始化方法，名字要统一
    );
    await metaNodeStakeProxy.waitForDeployment();
    console.log("代理合约地址：", await metaNodeStakeProxy.getAddress());
    const proxyAddress = await metaNodeStakeProxy.getAddress();
    const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log("部署：代理合约地址：", proxyAddress);
    console.log("部署：目标合约地址（实现合约地址）：", implAddress);

    const storePath = path.resolve(__dirname, "./.cache/proxyMetaNodeStake.json");
    
    fs.writeFileSync(
        storePath,
        JSON.stringify({
            proxyAddress,
            implAddress,
            abi: metaNodeStake.interface.format("json"),
        })
    );
    await save("MetaNodeStakeProxy", {
        abi: metaNodeStake.interface.format("json"),
        address: proxyAddress,
        // args: [],
        // log: true,
    });
};
module.exports.tags = ["deployMetaNodeStake"];