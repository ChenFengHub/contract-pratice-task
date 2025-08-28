const { deploy } = require("@openzeppelin/hardhat-upgrades/dist/utils");
const { ethers, upgrades }  = require("hardhat");
const { expect } = require("chai");
const {fs} = require("fs");
const {path} = require("path");
describe("Starting", () => {
    it("test deploy+upgrade", async () => {
        const {deployer, user1, user2} = await getNamedAccounts();
        let owner = deployer;
        let account2 =  user1;
        let account3 = user2;
        // const [owner, account2, account3] = await ethers.getSigners();

        // 1. 部署业务合约
        // fixture中指定的名字为 01_deploy_meme_token.js中module.exports.tags的名字
        await deployments.fixture(["deployDynamicToken"]);
        // 名字使用01_deploy_meme_token.js中save中保存的名字
        const DynamicTokenProxy = await deployments.get("DynamicTokenProxy");
        // 2. 调用createAuction方法创建拍卖
        // 使用已有的合约地址，创建合约
        const DynamicToken = await ethers.getContractAt(
            "DynamicToken", 
            DynamicTokenProxy.address
        );
        const dynamicTokenAddress = await DynamicToken.getAddress();
        console.log("DynamicToken合约地址：", dynamicTokenAddress);

        // 2. 验证交易的手续费
        await DynamicToken.mint(owner, 1000);
        await DynamicToken.mint(user1, 1000);
        await DynamicToken.mint(user2, 1000);


        console.log("before：Deployer address:", owner, "balance:", await DynamicToken.balanceOf(owner));
        console.log("before：account2   address:", account2, "balance:", await DynamicToken.balanceOf(account2));
        console.log("before：account3   address:", account3, "balance:", await DynamicToken.balanceOf(account3));
        let tx = await DynamicToken.transferMeme(owner, account3, 200);
        await tx.wait();
        console.log("after：Deployer address:", owner, "balance:", await DynamicToken.balanceOf(owner));
        console.log("after：account2   address:", account2, "balance:",  await DynamicToken.balanceOf(account2));
        console.log("after：account3   address:", account3, "balance:",  await DynamicToken.balanceOf(account3));
        

        // 3. 升级合约
        await deployments.fixture(["upgradeDynamicToken"]);
        const DynamicTokenProxyV2 = await deployments.get("DynamicTokenProxyV2");
        const DynamicToken2 = await ethers.getContractAt(
            "DynamicTokenV2", 
            DynamicTokenProxyV2.address
        );
        
        // 4. 对比更新后的合约是否地址是否不同
        const dynamicTokenAddress2 = await DynamicToken2.getAddress;
        expect(dynamicTokenAddress).to.not.equal(dynamicTokenAddress2, "升级后的合约地址和升级前的合约地址一致");
    });
});
