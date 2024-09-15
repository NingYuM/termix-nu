import { createRequire as __WEBPACK_EXTERNAL_createRequire } from "module";
/******/ var __webpack_modules__ = ({

/***/ 5:
/***/ ((module) => {

module.exports = __WEBPACK_EXTERNAL_createRequire(import.meta.url)("node:crypto");

/***/ }),

/***/ 561:
/***/ ((module) => {

module.exports = __WEBPACK_EXTERNAL_createRequire(import.meta.url)("node:fs");

/***/ }),

/***/ 433:
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __nccwpck_require__) => {

/* harmony export */ __nccwpck_require__.d(__webpack_exports__, {
/* harmony export */   "pJ": () => (/* binding */ base32)
/* harmony export */ });
/* unused harmony exports base16, base32hex, base64, base64url, codec */
/* eslint-disable @typescript-eslint/strict-boolean-expressions */
function parse(string, encoding, opts) {
  var _opts$out;

  if (opts === void 0) {
    opts = {};
  }

  // Build the character lookup table:
  if (!encoding.codes) {
    encoding.codes = {};

    for (var i = 0; i < encoding.chars.length; ++i) {
      encoding.codes[encoding.chars[i]] = i;
    }
  } // The string must have a whole number of bytes:


  if (!opts.loose && string.length * encoding.bits & 7) {
    throw new SyntaxError('Invalid padding');
  } // Count the padding bytes:


  var end = string.length;

  while (string[end - 1] === '=') {
    --end; // If we get a whole number of bytes, there is too much padding:

    if (!opts.loose && !((string.length - end) * encoding.bits & 7)) {
      throw new SyntaxError('Invalid padding');
    }
  } // Allocate the output:


  var out = new ((_opts$out = opts.out) != null ? _opts$out : Uint8Array)(end * encoding.bits / 8 | 0); // Parse the data:

  var bits = 0; // Number of bits currently in the buffer

  var buffer = 0; // Bits waiting to be written out, MSB first

  var written = 0; // Next byte to write

  for (var _i = 0; _i < end; ++_i) {
    // Read one character from the string:
    var value = encoding.codes[string[_i]];

    if (value === undefined) {
      throw new SyntaxError('Invalid character ' + string[_i]);
    } // Append the bits to the buffer:


    buffer = buffer << encoding.bits | value;
    bits += encoding.bits; // Write out some bits if the buffer has a byte's worth:

    if (bits >= 8) {
      bits -= 8;
      out[written++] = 0xff & buffer >> bits;
    }
  } // Verify that we have received just enough bits:


  if (bits >= encoding.bits || 0xff & buffer << 8 - bits) {
    throw new SyntaxError('Unexpected end of data');
  }

  return out;
}
function stringify(data, encoding, opts) {
  if (opts === void 0) {
    opts = {};
  }

  var _opts = opts,
      _opts$pad = _opts.pad,
      pad = _opts$pad === void 0 ? true : _opts$pad;
  var mask = (1 << encoding.bits) - 1;
  var out = '';
  var bits = 0; // Number of bits currently in the buffer

  var buffer = 0; // Bits waiting to be written out, MSB first

  for (var i = 0; i < data.length; ++i) {
    // Slurp data into the buffer:
    buffer = buffer << 8 | 0xff & data[i];
    bits += 8; // Write out as much as we can:

    while (bits > encoding.bits) {
      bits -= encoding.bits;
      out += encoding.chars[mask & buffer >> bits];
    }
  } // Partial character:


  if (bits) {
    out += encoding.chars[mask & buffer << encoding.bits - bits];
  } // Add padding characters until we hit a byte boundary:


  if (pad) {
    while (out.length * encoding.bits & 7) {
      out += '=';
    }
  }

  return out;
}

/* eslint-disable @typescript-eslint/strict-boolean-expressions */
var base16Encoding = {
  chars: '0123456789ABCDEF',
  bits: 4
};
var base32Encoding = {
  chars: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567',
  bits: 5
};
var base32HexEncoding = {
  chars: '0123456789ABCDEFGHIJKLMNOPQRSTUV',
  bits: 5
};
var base64Encoding = {
  chars: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/',
  bits: 6
};
var base64UrlEncoding = {
  chars: 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_',
  bits: 6
};
var base16 = {
  parse: function parse$1(string, opts) {
    return parse(string.toUpperCase(), base16Encoding, opts);
  },
  stringify: function stringify$1(data, opts) {
    return stringify(data, base16Encoding, opts);
  }
};
var base32 = {
  parse: function parse$1(string, opts) {
    if (opts === void 0) {
      opts = {};
    }

    return parse(opts.loose ? string.toUpperCase().replace(/0/g, 'O').replace(/1/g, 'L').replace(/8/g, 'B') : string, base32Encoding, opts);
  },
  stringify: function stringify$1(data, opts) {
    return stringify(data, base32Encoding, opts);
  }
};
var base32hex = {
  parse: function parse$1(string, opts) {
    return parse(string, base32HexEncoding, opts);
  },
  stringify: function stringify$1(data, opts) {
    return stringify(data, base32HexEncoding, opts);
  }
};
var base64 = {
  parse: function parse$1(string, opts) {
    return parse(string, base64Encoding, opts);
  },
  stringify: function stringify$1(data, opts) {
    return stringify(data, base64Encoding, opts);
  }
};
var base64url = {
  parse: function parse$1(string, opts) {
    return parse(string, base64UrlEncoding, opts);
  },
  stringify: function stringify$1(data, opts) {
    return stringify(data, base64UrlEncoding, opts);
  }
};
var codec = {
  parse: parse,
  stringify: stringify
};




/***/ }),

/***/ 695:
/***/ ((__webpack_module__, __webpack_exports__, __nccwpck_require__) => {

__nccwpck_require__.a(__webpack_module__, async (__webpack_handle_async_dependencies__, __webpack_async_result__) => { try {
/* harmony export */ __nccwpck_require__.d(__webpack_exports__, {
/* harmony export */   "$": () => (/* binding */ createBase32Hash),
/* harmony export */   "V": () => (/* binding */ createBase32HashFromFile)
/* harmony export */ });
/* harmony import */ var node_fs__WEBPACK_IMPORTED_MODULE_0__ = __nccwpck_require__(561);
/* harmony import */ var node_crypto__WEBPACK_IMPORTED_MODULE_1__ = __nccwpck_require__(5);
/* harmony import */ var rfc4648__WEBPACK_IMPORTED_MODULE_2__ = __nccwpck_require__(433);




function createBase32Hash (str) {
  return rfc4648__WEBPACK_IMPORTED_MODULE_2__/* .base32.stringify */ .pJ.stringify(node_crypto__WEBPACK_IMPORTED_MODULE_1__.createHash('md5').update(str).digest()).replace(/(=+)$/, '').toLowerCase()
}

async function createBase32HashFromFile (file) {
  const content = await node_fs__WEBPACK_IMPORTED_MODULE_0__.promises.readFile(file, 'utf8')
  return createBase32Hash(content.split('\r\n').join('\n'))
}

const fileName = process.argv[2];
if (!fileName) {
  console.error('请提供需要进行 base32hash 的文件名');
  process.exit(1);
}
const hash = await createBase32HashFromFile(fileName);
console.log(hash);

__webpack_async_result__();
} catch(e) { __webpack_async_result__(e); } }, 1);

/***/ })

/******/ });
/************************************************************************/
/******/ // The module cache
/******/ var __webpack_module_cache__ = {};
/******/ 
/******/ // The require function
/******/ function __nccwpck_require__(moduleId) {
/******/ 	// Check if module is in cache
/******/ 	var cachedModule = __webpack_module_cache__[moduleId];
/******/ 	if (cachedModule !== undefined) {
/******/ 		return cachedModule.exports;
/******/ 	}
/******/ 	// Create a new module (and put it into the cache)
/******/ 	var module = __webpack_module_cache__[moduleId] = {
/******/ 		// no module.id needed
/******/ 		// no module.loaded needed
/******/ 		exports: {}
/******/ 	};
/******/ 
/******/ 	// Execute the module function
/******/ 	var threw = true;
/******/ 	try {
/******/ 		__webpack_modules__[moduleId](module, module.exports, __nccwpck_require__);
/******/ 		threw = false;
/******/ 	} finally {
/******/ 		if(threw) delete __webpack_module_cache__[moduleId];
/******/ 	}
/******/ 
/******/ 	// Return the exports of the module
/******/ 	return module.exports;
/******/ }
/******/ 
/************************************************************************/
/******/ /* webpack/runtime/async module */
/******/ (() => {
/******/ 	var webpackQueues = typeof Symbol === "function" ? Symbol("webpack queues") : "__webpack_queues__";
/******/ 	var webpackExports = typeof Symbol === "function" ? Symbol("webpack exports") : "__webpack_exports__";
/******/ 	var webpackError = typeof Symbol === "function" ? Symbol("webpack error") : "__webpack_error__";
/******/ 	var resolveQueue = (queue) => {
/******/ 		if(queue && !queue.d) {
/******/ 			queue.d = 1;
/******/ 			queue.forEach((fn) => (fn.r--));
/******/ 			queue.forEach((fn) => (fn.r-- ? fn.r++ : fn()));
/******/ 		}
/******/ 	}
/******/ 	var wrapDeps = (deps) => (deps.map((dep) => {
/******/ 		if(dep !== null && typeof dep === "object") {
/******/ 			if(dep[webpackQueues]) return dep;
/******/ 			if(dep.then) {
/******/ 				var queue = [];
/******/ 				queue.d = 0;
/******/ 				dep.then((r) => {
/******/ 					obj[webpackExports] = r;
/******/ 					resolveQueue(queue);
/******/ 				}, (e) => {
/******/ 					obj[webpackError] = e;
/******/ 					resolveQueue(queue);
/******/ 				});
/******/ 				var obj = {};
/******/ 				obj[webpackQueues] = (fn) => (fn(queue));
/******/ 				return obj;
/******/ 			}
/******/ 		}
/******/ 		var ret = {};
/******/ 		ret[webpackQueues] = x => {};
/******/ 		ret[webpackExports] = dep;
/******/ 		return ret;
/******/ 	}));
/******/ 	__nccwpck_require__.a = (module, body, hasAwait) => {
/******/ 		var queue;
/******/ 		hasAwait && ((queue = []).d = 1);
/******/ 		var depQueues = new Set();
/******/ 		var exports = module.exports;
/******/ 		var currentDeps;
/******/ 		var outerResolve;
/******/ 		var reject;
/******/ 		var promise = new Promise((resolve, rej) => {
/******/ 			reject = rej;
/******/ 			outerResolve = resolve;
/******/ 		});
/******/ 		promise[webpackExports] = exports;
/******/ 		promise[webpackQueues] = (fn) => (queue && fn(queue), depQueues.forEach(fn), promise["catch"](x => {}));
/******/ 		module.exports = promise;
/******/ 		body((deps) => {
/******/ 			currentDeps = wrapDeps(deps);
/******/ 			var fn;
/******/ 			var getResult = () => (currentDeps.map((d) => {
/******/ 				if(d[webpackError]) throw d[webpackError];
/******/ 				return d[webpackExports];
/******/ 			}))
/******/ 			var promise = new Promise((resolve) => {
/******/ 				fn = () => (resolve(getResult));
/******/ 				fn.r = 0;
/******/ 				var fnQueue = (q) => (q !== queue && !depQueues.has(q) && (depQueues.add(q), q && !q.d && (fn.r++, q.push(fn))));
/******/ 				currentDeps.map((dep) => (dep[webpackQueues](fnQueue)));
/******/ 			});
/******/ 			return fn.r ? promise : getResult();
/******/ 		}, (err) => ((err ? reject(promise[webpackError] = err) : outerResolve(exports)), resolveQueue(queue)));
/******/ 		queue && (queue.d = 0);
/******/ 	};
/******/ })();
/******/ 
/******/ /* webpack/runtime/define property getters */
/******/ (() => {
/******/ 	// define getter functions for harmony exports
/******/ 	__nccwpck_require__.d = (exports, definition) => {
/******/ 		for(var key in definition) {
/******/ 			if(__nccwpck_require__.o(definition, key) && !__nccwpck_require__.o(exports, key)) {
/******/ 				Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 			}
/******/ 		}
/******/ 	};
/******/ })();
/******/ 
/******/ /* webpack/runtime/hasOwnProperty shorthand */
/******/ (() => {
/******/ 	__nccwpck_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ })();
/******/ 
/******/ /* webpack/runtime/compat */
/******/ 
/******/ if (typeof __nccwpck_require__ !== 'undefined') __nccwpck_require__.ab = new URL('.', import.meta.url).pathname.slice(import.meta.url.match(/^file:\/\/\/\w:/) ? 1 : 0, -1) + "/";
/******/ 
/************************************************************************/
/******/ 
/******/ // startup
/******/ // Load entry module and return exports
/******/ // This entry module used 'module' so it can't be inlined
/******/ var __webpack_exports__ = __nccwpck_require__(695);
/******/ __webpack_exports__ = await __webpack_exports__;
/******/ var __webpack_exports__createBase32Hash = __webpack_exports__.$;
/******/ var __webpack_exports__createBase32HashFromFile = __webpack_exports__.V;
/******/ export { __webpack_exports__createBase32Hash as createBase32Hash, __webpack_exports__createBase32HashFromFile as createBase32HashFromFile };
/******/ 
