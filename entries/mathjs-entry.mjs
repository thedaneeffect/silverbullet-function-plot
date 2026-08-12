import { parse } from 'mathjs';

// function-plot spells the constant PI; mathjs typesets `pi` as the Greek letter.
export function exprToTex(expr) {
  return parse(expr.replace(/\bPI\b/g, 'pi')).toTex();
}

export default { exprToTex };
