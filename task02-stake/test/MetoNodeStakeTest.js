const { deploy } = require("@openzeppelin/hardhat-upgrades/dist/utils");
const { ethers, upgrades, getNamedAccounts }  = require("hardhat");
const { expect } = require("chai");
const {fs} = require("fs");
const {path} = require("path");
describe("Starting", () => {
    it("test deploy+upgrade", async () => {
        // 获取signer对象而不是地址字符串
        const {owner, account2, account3} = await getNamedAccounts();
        console.log("owner:", owner);
        console.log("account2:", account2);
        console.log("account3:", account3);

        // 获取对应的 signer
        const ownerSigner = await ethers.getSigner(owner);
        const account2Signer = await ethers.getSigner(account2);
        const account3Signer = await ethers.getSigner(account3);
        
        // 1. 部署业务合约
        // fixture中指定的名字为 01_deploy_meme_token.js中module.exports.tags的名字
        await deployments.fixture(["deployMetaNodeStake"]);
        // 名字使用01_deploy_meme_token.js中save中保存的名字
        console.log("MetaNodeStake begin...");
        const MetaNodeStakeProxy = await deployments.get("MetaNodeStakeProxy");
        console.log("MetaNodeStake end...");
        // 2. 创建ERC20代币，并给每个用户mint
        const MyToken = await ethers.getContractFactory("MyToken");
        const myToken = await MyToken.deploy();
        await myToken.waitForDeployment();
        const myTokenAddress = await myToken.getAddress();
        console.log("MyToken合约地址：", myTokenAddress);
        await myToken.mint(owner, 1000);
        await myToken.mint(account2, 1000);
        await myToken.mint(account3, 1000);
       
        // 3.使用已有的合约地址，创建合约
        const MetaNodeStake = await ethers.getContractAt(
            "MetaNodeStake", 
            MetaNodeStakeProxy.address
        );
        const MetaNodeStakeAddress = await MetaNodeStake.getAddress();
        console.log("MetaNodeStake合约地址：", MetaNodeStakeAddress);


        console.log("before-owner MyToken合约余额：", await myToken.balanceOf(owner));
        console.log("before-account2 MyToken合约余额：", await myToken.balanceOf(account2));
        console.log("before-account3 MyToken合约余额：", await myToken.balanceOf(account3));

        console.log("before-owner ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(owner), 18));
        console.log("before-account2 ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(account2), 18));
        console.log("before-account3 ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(account3), 18));

        console.log("before-owner MetaNode合约余额：", await MetaNodeStake.balanceOf(owner));
        console.log("before-account2 MetaNode合约余额：", await MetaNodeStake.balanceOf(account2));
        console.log("before-account3 MetaNode合约余额：", await MetaNodeStake.balanceOf(account3));

        // 4. 添加ETH池和MyToken的池子
        // 添加ETH池
        // view和pure类型方法可以直接获取结果
        const ETHPoolExist = await MetaNodeStake.isPoolExist(0);
        let ehtPoolId = 0;
        if (!ETHPoolExist) {
            const ethTx = await MetaNodeStake.addPool(ethers.ZeroAddress, 60, 1, 1);
            const receipt = await ethTx.wait();
            const returnValue = receipt.logs[0].data;
            ehtPoolId = ethers.AbiCoder.defaultAbiCoder().decode(['uint256'], returnValue)[0];
            console.log("EHT Pool ID:", ehtPoolId.toString());
        }
        // 添加MyToken池
        const MyTokenPoolExist = await MetaNodeStake.isPoolExist(1);
        let myTokenPoolId = 1;
        if (!MyTokenPoolExist) {
            const MyTokenTx = await MetaNodeStake.addPool(myTokenAddress, 40, 1, 1);
            const receipt = await MyTokenTx.wait();
            const returnValue = receipt.logs[0].data;
            myTokenPoolId = ethers.AbiCoder.defaultAbiCoder().decode(['uint256'], returnValue)[0];
            console.log("MyToken Pool ID:", myTokenPoolId.toString());
        }
        
        // 5. 用户进行质押
        // eth 池中进行质押
        await MetaNodeStake.connect(account2Signer).stakeETH(ehtPoolId, {value: ethers.parseEther("0.001")});
        await MetaNodeStake.connect(account3Signer).stakeETH(ehtPoolId, {value: ethers.parseEther("0.002")});
        // myToken池中进行质押
        await myToken.connect(account2Signer).approve(MetaNodeStakeAddress, 800);
        await myToken.connect(account3Signer).approve(MetaNodeStakeAddress, 900);
        await MetaNodeStake.connect(account2Signer).stakeToken(myTokenPoolId, 800);
        await MetaNodeStake.connect(account3Signer).stakeToken(myTokenPoolId, 900);
        console.log("staking-owner MyToken合约余额：", await myToken.balanceOf(owner));
        console.log("staking-account2 MyToken合约余额：", await myToken.balanceOf(account2));
        console.log("staking-account3 MyToken合约余额：", await myToken.balanceOf(account3));

        console.log("staking-owner ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(owner), 18));
        console.log("staking-account2 ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(account2), 18));
        console.log("staking-account3 ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(account3), 18));
        
        console.log("staking-owner MetaNode合约余额：", await MetaNodeStake.balanceOf(owner));
        console.log("staking-account2 MetaNode合约余额：", await MetaNodeStake.balanceOf(account2));
        console.log("staking-account3 MetaNode合约余额：", await MetaNodeStake.balanceOf(account3));


        // 6. 接触质押并提取、领取奖励
        // ETH
        // 调用unStake的gas消耗由调用者进行支付，所以如下把合约内部ETH全部转出对于合约本身是没有额外GAS消耗，是能全部转出的，所需如下代码可以注释
        // await ownerSigner.sendTransaction({    
        //     to: MetaNodeStakeAddress,
        //     value: ethers.parseEther("0.01") // 发送1 ETH到合约，充当GAS
        // });
        // 需要先往合约里多充点ETH，否则合约本身的ETH不够支付GAS将ETH原路退回
        await MetaNodeStake.connect(account2Signer).unStake(ehtPoolId, ethers.parseEther("0.001"));
        await MetaNodeStake.connect(account3Signer).unStake(ehtPoolId, ethers.parseEther("0.002"));
        await MetaNodeStake.connect(account2Signer).claimReward(ehtPoolId);
        await MetaNodeStake.connect(account3Signer).claimReward(ehtPoolId);
        await MetaNodeStake.connect(account2Signer).withdraw(ehtPoolId);
        await MetaNodeStake.connect(account3Signer).withdraw(ehtPoolId);
        // MyToken
        await MetaNodeStake.connect(account2Signer).unStake(myTokenPoolId, 400);
        await MetaNodeStake.connect(account3Signer).unStake(myTokenPoolId, 800);
        await MetaNodeStake.connect(account2Signer).claimReward(myTokenPoolId);
        await MetaNodeStake.connect(account3Signer).claimReward(myTokenPoolId);
        await MetaNodeStake.connect(account2Signer).withdraw(myTokenPoolId);
        await MetaNodeStake.connect(account3Signer).withdraw(myTokenPoolId);

        console.log("after-owner MyToken合约余额：", await myToken.balanceOf(owner));
        console.log("after-account2 MyToken合约余额：", await myToken.balanceOf(account2));
        console.log("after-account3 MyToken合约余额：", await myToken.balanceOf(account3));

        console.log("after-owner ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(owner), 18));
        console.log("after-account2 ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(account2), 18));
        console.log("after-account3 ETH余额：", ethers.formatUnits(await ethers.provider.getBalance(account3), 18));
        
        console.log("after-owner MetaNode合约余额：", await MetaNodeStake.balanceOf(owner));
        console.log("after-account2 MetaNode合约余额：", await MetaNodeStake.balanceOf(account2));
        console.log("after-account3 MetaNode合约余额：", await MetaNodeStake.balanceOf(account3));
    
        // 7. 暂停质押和提取
        await MetaNodeStake.pauseStake();
        try {
            await MetaNodeStake.connect(account2Signer).stakeETH(ehtPoolId, {value: ethers.parseEther("10")});
        } catch (error) {
            console.log("ETH暂停质押成功");
        }
        try {
            await MetaNodeStake.connect(account2Signer).stakeToken(myTokenPoolId, 800);
        } catch (error) {
            console.log("MyToken暂停质押成功");
        }
        try {
            await MetaNodeStake.connect(account2Signer).withdraw(ehtPoolId, ethers.parseEther("10"));
        } catch (error) {
            console.log("ETH暂停提取成功");
        }
        try {
             await MetaNodeStake.connect(account2Signer).withdraw(myTokenPoolId);
        } catch (error) {
            console.log("MyToken暂停提取成功");
        }
        
        // 8. 升级合约
        await deployments.fixture(["upgradeMetaNodeStake"]);
        const MetaNodeStakeProxyV2 = await deployments.get("MetaNodeStakeProxyV2");
        const MetaNodeStake2 = await ethers.getContractAt(
            "MetaNodeStakeV2", 
            MetaNodeStakeProxyV2.address
        );
        
        // 4. 对比更新后的合约是否地址是否不同
        const MetaNodeStakeAddress2 = await MetaNodeStake2.getAddress;
        expect(MetaNodeStakeAddress).to.not.equal(MetaNodeStakeAddress2, "升级后的合约地址和升级前的合约地址一致");
    }).timeout(5 * 60 * 1000); // 默认为40s,而sepolia上部署可能比较慢
});
