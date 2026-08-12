import mathMod from '../Function-Plot/mathjs-parse.mjs';
import fpMod from '../Function-Plot/function-plot.mjs';

const tex = mathMod.exprToTex('sin(x) / x');
if (!tex.includes('\\frac')) throw new Error(`no \\frac in: ${tex}`);
if (!tex.includes('\\sin')) throw new Error(`no \\sin in: ${tex}`);
if (mathMod.exprToTex('PI * x').includes('PI')) throw new Error('PI alias failed');
if (typeof fpMod.render !== 'function') throw new Error('function-plot render missing');
console.log('smoke ok');
