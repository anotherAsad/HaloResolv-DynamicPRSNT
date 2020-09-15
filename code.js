function genVerilog(sendHaloArr, recvHaloArr, incrArr, p, LINWDTH, ADDRLEN){
	// prepend zeros
	var extend = function(str, len){
		if(len == undefined)
			len = 2;
		if(typeof(str) != "string")		// Because a number was sent
			str = String(str);
		var repChar = str[0] == "x" ? "x" : "0";
		while(str.length < len)
			str = repChar+str;
		return str;
	};
	// Represent Negative Numbers in 2's complement
	var norm = function(num){
		if(num < 0)
			num = 2**(LINWDTH-ADDRLEN)+num;	// '+' not '-' because already negative
		return num;
	};
	//
	var RAMCNT = 2**ADDRLEN;
	var len = String(LINWDTH-ADDRLEN);
	// EXTRACT en, initHalo, lastHalo FROM haloArr
	var initHaloSend = "#0 initHaloSend = {";
	var lastHaloSend = "#0 lastHaloSend = {";
	var initHaloRecv = "#0 initHaloRecv = {";
	var lastHaloRecv = "#0 lastHaloRecv = {";
	var haloSend, haloRecv;		// Accumulator for strings later.
	var en = "1".repeat(RAMCNT).split("");	// Becase immutable js strings
	// Send Halo String Magic
	for(var x in sendHaloArr){
		var y = RAMCNT-x-1;
		if(sendHaloArr[y][0] == undefined){	// both [x][0] and [x][1] undefined at once
			en[y] = "0";// sendHalo
			initHaloSend += len + "\'d" + extend("x") + ", ";
			lastHaloSend += len + "\'d" + extend("x") + ", ";
		}
		else {
			initHaloSend += len + "\'d" + extend(norm(sendHaloArr[y][0])) + ", ";
			lastHaloSend += len + "\'d" + extend(norm(sendHaloArr[y][1])) + ", ";
		}
	}
	// Recv Halo String Magic
	for(var x in recvHaloArr){
		var y = RAMCNT-x-1;
		if(recvHaloArr[y][0] == undefined){	// both [x][0] and [x][1] undefined at once
			en[y] = "0";// sendHalo
			initHaloRecv += len + "\'d" + extend("x") + ", ";
			lastHaloRecv += len + "\'d" + extend("x") + ", ";
		}
		else {
			initHaloRecv += len + "\'d" + extend(norm(recvHaloArr[y][0])) + ", ";
			lastHaloRecv += len + "\'d" + extend(norm(recvHaloArr[y][1])) + ", ";
		}
	}
	// Join Up
	en = en.join(", 1\'b");
	en = "#0 en = {1\'b" + en + "};<br>";
	initHaloSend = initHaloSend.substring(0, initHaloSend.length-2) + "};<br>";
	lastHaloSend = lastHaloSend.substring(0, lastHaloSend.length-2) + "};<br>";
	initHaloRecv = initHaloRecv.substring(0, initHaloRecv.length-2) + "};<br>";
	lastHaloRecv = lastHaloRecv.substring(0, lastHaloRecv.length-2) + "};<br>";
	haloSend = initHaloSend + lastHaloSend;
	haloRecv = initHaloRecv + lastHaloRecv;
	// EXTRACT incrVal, incrTrig FROM incrArr
	var [incrVal, incrTrg] = ["#0 incrVal  = {", "#0 incrTrg  = {"];
	for(var x in incrArr){
		incrTrg += len + "\'d" + incrArr[2-x][0] + ", ";
		incrVal += len + "\'d" + incrArr[2-x][1] + ", ";
	}
	incrTrg = incrTrg.substring(0, incrTrg.length-2) + "};<br>";
	incrVal = incrVal.substring(0, incrVal.length-2) + "};<br>";
	// EXTRACT EOF, NUMITERS from EOF, NUMFRAMES
	var constStr = "#0 EOF = 'd" + p.EOF + "; #0 NUMITERS = 'd" + p.NUMITERS +";";
	constStr += " #0 RAMROT = 'd" + p.ramRot + ";<br>"
	// Final Patch Up
	var str = constStr + en + haloSend + haloRecv + incrVal + incrTrg;
	var str = "<pre>" + str + "</pre>";
	document.clear();
	document.write(str);
	return en;
}

// This function simulates an iterator model for hardware.
function iterator(initOffset, lastHalo, incrArr, EOF, clkCount, ramNum){
	var res = [];
	var [base, offset] = [0, initOffset];
	// Should model hardware. Notice the underuse of frameLen.
	for(var i=0; i<clkCount; i++){
		var incr;
		// Please add redundancy in meta
		if(incrArr.length > 2 && offset>=incrArr[2][0])
			incr = incrArr[2][1];
		else if(incrArr.length > 1 && offset>=incrArr[1][0])
			incr = incrArr[1][1];
		else
			incr = incrArr[0][1];
		// Save addr
		res.push(base+offset);
		// Update Offset and Base
		if(offset == lastHalo)
			[base, offset] = [base+EOF, initOffset];
		else
			offset = (offset + incr)%EOF;
	}
	return {
		"sendArr": res,
	}
}

// Faster algorithm may use separate even-odd iterators
function lcm(a, b){
	if(a > b)
		[a, b] = [b, a];
	// now a LTE b is TRUE
	var factorProd = 1;
	var i = a;
	// Eliminate common Factors
	while(i > 1)
		if(a%i==0 && b%i==0){
			a=a/i;
			b=b/i;
			factorProd *= i;
			i = a;
		}
		else {
			i = (i==a) ? Math.floor(a/2) : i-1;
		}
	// return LCM
	return a*b*factorProd;
}

// For a given framelength, calculates the next valid halo distance.
function distNext(incr, frameLen, EOF){
	if(frameLen >= EOF){ // Guard. Expect @defunct and his abysmal memory to fix it.
		console.log("HEED: frameLen >= EOF");
		return [[0, incr], [0, incr], [0, incr]];
	}
	// multiple incr Hunt
	var arr = [];
	for(var i=0; i<frameLen; i++){
		var temp = i;
		var mulIndex = 1;
		while((temp+incr)%EOF >= frameLen && mulIndex++)
			temp = (temp+incr)%EOF;
		if(arr[0] == undefined || arr[arr.length-1][1] != mulIndex)
			arr.push([i, mulIndex]);
	}
	// scale mulIndex to give actual increment values. Contain in EOF
	for(var i in arr)
		arr[i][1] = (arr[i][1] * incr) % EOF;
	// redundant append for the iterator
	while(arr.length < 3)
		arr.push(arr[arr.length-1]);
	return arr;
}

// Caluculate ADDRESSES of initHalo and lastHalo
function getHaloAddrs(repIndex, haloCount, frameLen, RAMCNT, OUTLEN, backResolve){
	var arr = []
	// Range failure check protects in more than one way
	for(var ramNum=0; ramNum<RAMCNT; ramNum++){
		var [initHalo, lastHalo] = [0, 0];
		var iniDist, finDist;
		iniDist = finDist = ramNum%repIndex;
		for(var i=0; i<frameLen; i++){	// 0th iter can not be averted.
			var potentialDist = (i*RAMCNT+ramNum)%repIndex;
			var rangeFailure, iniOKFailure, finOKFailure;
			// Setup Conditions
			if(backResolve){
				rangeFailure = potentialDist < OUTLEN-haloCount;
				iniOKFailure = iniDist < OUTLEN-haloCount;
				finOKFailure = finDist < OUTLEN-haloCount;
			}
			else {
				rangeFailure = potentialDist >= haloCount;
				iniOKFailure = iniDist >= haloCount;
				finOKFailure = finDist >= haloCount;
			}
			// Action Section.
			if(rangeFailure)
				continue;
			if(iniOKFailure || potentialDist < iniDist)
				[initHalo, iniDist] = [i, potentialDist];
			if(finOKFailure || potentialDist > finDist)
				[lastHalo, finDist] = [i, potentialDist];

		}
		// No Halos to Send
		if(iniOKFailure)
			initHalo = undefined;
		if(finOKFailure)		// Both have got to be true at once.
			lastHalo = undefined;
		arr.push([initHalo, lastHalo]);
	}
	return arr;
}

// The parameters for distNext. DEPTH may not be needed.
function getParams(haloCount, RAMCNT, NUMFRAMES, OUTLEN, DIR){
	var repIndex = DIR=="UP" ? OUTLEN**2 : OUTLEN;
	var EOF = lcm(repIndex, RAMCNT)/RAMCNT;
	var frameLen = Math.ceil((OUTLEN**2*NUMFRAMES)/RAMCNT);
	// Find out the smallest incr to land index to very next frameVal.
	var minInd = 1;
	var minDist = (minInd * RAMCNT) % repIndex;
	for(var i=2; i<EOF; i++){
		var potentialMinDist = (i*RAMCNT)%repIndex;
		if(potentialMinDist < minDist){
			minInd = i;
			minDist = potentialMinDist;
		}
	}
	// Figure RamRot
	var haloDist = DIR=="UP" ? OUTLEN**2-haloCount : OUTLEN-haloCount;
	var ramRot = haloDist % RAMCNT;
	// Framlen 19 means from 0-18. EOF 81 means 0-80.
	// Incr is minDist index irrespective of framelen
	return {
		"incr": minInd,
		"frameLen": frameLen > EOF ? EOF: frameLen,
		"EOF": EOF,
		"repIndex": repIndex,
		"ramRot": ramRot,
		"NUMITERS": Math.ceil(frameLen/EOF)	// un-updated value of frameLen used
	};
}

clear();
var RAMCNT=16, NUMFRAMES=1, OUTLEN=5, DIR="LEFT";
var ramNum=0, ramAddr=0, haloCount=2, backResolve;
var clkCount = 10;
// Get Parameters
var p = getParams(haloCount, RAMCNT, NUMFRAMES, OUTLEN, DIR);
var a = getHaloAddrs(p.repIndex, haloCount, p.frameLen, RAMCNT, OUTLEN, backResolve=0);
var b = getHaloAddrs(p.repIndex, haloCount, p.frameLen, RAMCNT, OUTLEN, backResolve=1);
var [initHalo, lastHalo] = a[ramNum];
var arr = distNext(p.incr, p.frameLen, p.EOF);
// Invoke hardware simulator
var res = iterator(initHalo, lastHalo, arr, p.EOF, clkCount, ramNum);
// Invoke Verilog generator
// var str =  genVerilog(a, b, arr, p, LINWDTH, ADDRLEN);
// Logs
console.log(p);
console.log(arr);
console.log({"initHalo": initHalo, "lastHalo": lastHalo});
console.log("sendArr", res.sendArr);
console.clear();
console.log(
	arr[0][0], arr[0][1], "\n",
	arr[1][0], arr[1][1], "\n",
	arr[2][0], arr[2][1]
);

