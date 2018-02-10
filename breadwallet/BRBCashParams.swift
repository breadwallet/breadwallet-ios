//
//  BRBCashParams.swift
//
//  Created by Aaron Voisine on 1/10/18.
//  Copyright (c) 2019 breadwallet LLC
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import BRCore

let BRBCashDNSSeeds: Array<UnsafePointer<Int8>?> =
    [UnsafePointer<Int8>("seed-abc.breadwallet.com."), UnsafePointer<Int8>("seed.bitcoinabc.org."),
     UnsafePointer<Int8>("seed-abc.bitcoinforks.org."), UnsafePointer<Int8>("seed.bitcoinunlimited.info."),
     UnsafePointer<Int8>("seed.bitprim.org."), UnsafePointer<Int8>("seed.deadalnix.me."), nil]

let BRBCashTestNetDNSSeeds: Array<UnsafePointer<Int8>?> =
    [UnsafePointer<Int8>("testnet-seed.bitcoinabc.org"), UnsafePointer<Int8>("testnet-seed-abc.bitcoinforks.org"),
     UnsafePointer<Int8>("testnet-seed.bitprim.org"), UnsafePointer<Int8>("testnet-seed.deadalnix.me"),
     UnsafePointer<Int8>("testnet-seeder.criptolayer.net"), nil]

extension BRCheckPoint {
    init(_ height: UInt32, _ hash: String, _ timestamp: UInt32, _ target: UInt32) {
        self.init(height: height, hash: UInt256(hash), timestamp: timestamp, target: target)
    }
}

let BRBCashCheckpoints =
    [BRCheckPoint(     0, "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f", 1231006505, 0x1d00ffff),
     BRCheckPoint( 20160, "000000000f1aef56190aee63d33a373e6487132d522ff4cd98ccfc96566d461e", 1248481816, 0x1d00ffff),
     BRCheckPoint( 40320, "0000000045861e169b5a961b7034f8de9e98022e7a39100dde3ae3ea240d7245", 1266191579, 0x1c654657),
     BRCheckPoint( 60480, "000000000632e22ce73ed38f46d5b408ff1cff2cc9e10daaf437dfd655153837", 1276298786, 0x1c0eba64),
     BRCheckPoint( 80640, "0000000000307c80b87edf9f6a0697e2f01db67e518c8a4d6065d1d859a3a659", 1284861847, 0x1b4766ed),
     BRCheckPoint(100800, "000000000000e383d43cc471c64a9a4a46794026989ef4ff9611d5acb704e47a", 1294031411, 0x1b0404cb),
     BRCheckPoint(120960, "0000000000002c920cf7e4406b969ae9c807b5c4f271f490ca3de1b0770836fc", 1304131980, 0x1b0098fa),
     BRCheckPoint(141120, "00000000000002d214e1af085eda0a780a8446698ab5c0128b6392e189886114", 1313451894, 0x1a094a86),
     BRCheckPoint(161280, "00000000000005911fe26209de7ff510a8306475b75ceffd434b68dc31943b99", 1326047176, 0x1a0d69d7),
     BRCheckPoint(181440, "00000000000000e527fc19df0992d58c12b98ef5a17544696bbba67812ef0e64", 1337883029, 0x1a0a8b5f),
     BRCheckPoint(201600, "00000000000003a5e28bef30ad31f1f9be706e91ae9dda54179a95c9f9cd9ad0", 1349226660, 0x1a057e08),
     BRCheckPoint(221760, "00000000000000fc85dd77ea5ed6020f9e333589392560b40908d3264bd1f401", 1361148470, 0x1a04985c),
     BRCheckPoint(241920, "00000000000000b79f259ad14635739aaf0cc48875874b6aeecc7308267b50fa", 1371418654, 0x1a00de15),
     BRCheckPoint(262080, "000000000000000aa77be1c33deac6b8d3b7b0757d02ce72fffddc768235d0e2", 1381070552, 0x1916b0ca),
     BRCheckPoint(282240, "0000000000000000ef9ee7529607286669763763e0c46acfdefd8a2306de5ca8", 1390570126, 0x1901f52c),
     BRCheckPoint(302400, "0000000000000000472132c4daaf358acaf461ff1c3e96577a74e5ebf91bb170", 1400928750, 0x18692842),
     BRCheckPoint(322560, "000000000000000002df2dd9d4fe0578392e519610e341dd09025469f101cfa1", 1411680080, 0x181fb893),
     BRCheckPoint(342720, "00000000000000000f9cfece8494800d3dcbf9583232825da640c8703bcd27e7", 1423496415, 0x1818bb87),
     BRCheckPoint(362880, "000000000000000014898b8e6538392702ffb9450f904c80ebf9d82b519a77d5", 1435475246, 0x1816418e),
     BRCheckPoint(383040, "00000000000000000a974fa1a3f84055ad5ef0b2f96328bc96310ce83da801c9", 1447236692, 0x1810b289),
     BRCheckPoint(403200, "000000000000000000c4272a5c68b4f55e5af734e88ceab09abf73e9ac3b6d01", 1458292068, 0x1806a4c3),
     BRCheckPoint(423360, "000000000000000001630546cde8482cc183708f076a5e4d6f51cd24518e8f85", 1470163842, 0x18057228),
     BRCheckPoint(443520, "00000000000000000345d0c7890b2c81ab5139c6e83400e5bed00d23a1f8d239", 1481765313, 0x18038b85),
     BRCheckPoint(463680, "000000000000000000431a2f4619afe62357cd16589b638bb638f2992058d88e", 1493259601, 0x18021b3e),
     BRCheckPoint(483840, "00000000000000000098963251fcfc19d0fa2ef05cf22936a182609f8d650346", 1503802540, 0x1803c5d5),
     BRCheckPoint(504000, "0000000000000000006cdeece5716c9c700f34ad98cb0ed0ad2c5767bbe0bc8c", 1510516839, 0x18021abd)]

let BRBCashTestNetCheckpoints =
    [BRCheckPoint(      0, "000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943", 1296688602, 0x1d00ffff),
     BRCheckPoint( 100800, "0000000000a33112f86f3f7b0aa590cb4949b84c2d9c673e9e303257b3be9000", 1376543922, 0x1c00d907),
     BRCheckPoint( 201600, "0000000000376bb71314321c45de3015fe958543afcbada242a3b1b072498e38", 1393813869, 0x1b602ac0),
     BRCheckPoint( 302400, "0000000000001c93ebe0a7c33426e8edb9755505537ef9303a023f80be29d32d", 1413766239, 0x1a33605e),
     BRCheckPoint( 403200, "0000000000ef8b05da54711e2106907737741ac0278d59f358303c71d500f3c4", 1431821666, 0x1c02346c),
     BRCheckPoint( 504000, "0000000000005d105473c916cd9d16334f017368afea6bcee71629e0fcf2f4f5", 1436951946, 0x1b00ab86),
     BRCheckPoint( 604800, "00000000000008653c7e5c00c703c5a9d53b318837bb1b3586a3d060ce6fff2e", 1447484641, 0x1a092a20),
     BRCheckPoint( 705600, "00000000004ee3bc2e2dd06c31f2d7a9c3e471ec0251924f59f222e5e9c37e12", 1455728685, 0x1c0ffff0),
     BRCheckPoint( 806400, "0000000000000faf114ff29df6dbac969c6b4a3b407cd790d3a12742b50c2398", 1462006183, 0x1a34e280),
     BRCheckPoint( 907200, "0000000000166938e6f172a21fe69fe335e33565539e74bf74eeb00d2022c226", 1469705562, 0x1c00ffff),
     BRCheckPoint(1008000, "000000000000390aca616746a9456a0d64c1bd73661fd60a51b5bf1c92bae5a0", 1476926743, 0x1a52ccc0),
     BRCheckPoint(1108800, "00000000000288d9a219419d0607fb67cc324d4b6d2945ca81eaa5e739fab81e", 1490751239, 0x1b09ecf0)]

public let BRBCashParams =
    BRChainParams(dnsSeeds: BRBCashDNSSeeds, standardPort: 8333, magicNumber: 0xe8f3e1e3, services: 0,
                  verifyDifficulty: BRTestNetVerifyDifficulty,
                  checkpoints: BRBCashCheckpoints, checkpointsCount: BRBCashCheckpoints.count)

public let BRBCashTestNetParams =
    BRChainParams(dnsSeeds: BRBCashTestNetDNSSeeds, standardPort: 18333, magicNumber: 0xf4f3e5f4, services: 0,
                  verifyDifficulty: BRTestNetVerifyDifficulty,
                  checkpoints: BRBCashTestNetCheckpoints, checkpointsCount: BRBCashTestNetCheckpoints.count)

