#!/usr/bin/env node
// Writes the certify job summary (Markdown) to $GITHUB_STEP_SUMMARY, or to
// stdout when that variable is unset. Inputs come only from env (KYA_STATUS,
// KYA_EXIT_CODE, KYA_REPORT_PATH, KYA_WINDOW_DAYS, KYA_FAIL_ON, KYA_FOOTER),
// never from ${{ }} interpolation, as in certify.sh.
//
// The report is PR data. It is opened with O_NOFOLLOW, as the PR comment step
// does, and every text field from it is escaped before it goes into Markdown.
// ponytail: whole report is read into memory; reports are small JSON files.
'use strict';

const fs = require('fs');

const SEVERITY_RANK = { critical: 0, high: 1, medium: 2, low: 3 };
const HOSTED_HISTORY_URL = 'https://shield-agent.com/';

// Escapes Markdown syntax and removes line breaks. Long values are cut.
function md(text, max = 200) {
  const s = String(text ?? '').replace(/[\r\n]+/g, ' ').trim();
  const cut = s.length > max ? `${s.slice(0, max - 3)}...` : s;
  return cut.replace(/[\\`*_[\]<>|#~&!]/g, (c) => `\\${c}`);
}

// Keeps the summary part of evidence ("summary - remediation hint").
function firstSentence(text) {
  if (!text) return '';
  const summary = String(text).split(/\s+\u2014\s+/)[0].trim();
  const m = summary.match(/^.*?[.!?](?=\s|$)/);
  return (m ? m[0] : summary.slice(0, 160)).trim();
}

function readReport(reportPath) {
  if (!reportPath) return null;
  let fd;
  try {
    fd = fs.openSync(reportPath, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0));
    return JSON.parse(fs.readFileSync(fd, 'utf8'));
  } catch (e) {
    console.log(`::warning title=kya certify::Could not read the certify report: ${e.message}`);
    return null;
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
  }
}

// Returns the Verdict line. The step fails only when fail-on is not never
// and certify did not pass (gap or error). Empty fail-on means the default, gap.
function verdict(status, failOn, gapCount) {
  const gateOn = failOn !== 'never';
  if (status === 'pass') return 'passed. No gaps were found.';
  if (status === 'gap') {
    return gateOn
      ? `failed. ${gapCount} gap(s) found, and fail-on is gap, so this step fails.`
      : 'gaps found. Report only, because fail-on is never.';
  }
  return gateOn
    ? 'failed. kya certify did not complete, so this step fails.'
    : 'error. kya certify did not complete. Report only, because fail-on is never.';
}

function render(env, report) {
  const status = env.status === 'pass' || env.status === 'gap' ? env.status : 'error';
  const ran = env.status !== '';
  const failOn = env.failOn === 'never' ? 'never' : 'gap';
  const requirements = Array.isArray(report?.requirements) ? report.requirements : [];
  const overall = report?.overall ?? {};
  const num = (v) => (Number.isFinite(v) ? v : 0);
  const passed = num(overall.pass) || requirements.filter((r) => r.status === 'pass').length;
  const gaps = requirements
    .filter((r) => r.status === 'gap')
    .sort((a, b) => (SEVERITY_RANK[a.severity] ?? 9) - (SEVERITY_RANK[b.severity] ?? 9));
  const gapCount = num(overall.gap) || gaps.length;
  const insufficient = num(overall.insufficientEvidence)
    || requirements.filter((r) => r.status === 'insufficient_evidence').length;

  const lines = ['## KYA Certify: Agent Trust Baseline', ''];
  if (!ran) {
    // The install step failed, so the job fails whatever fail-on says.
    lines.push('**Verdict:** failed. kya certify did not run. See the workflow logs.', '');
  } else {
    lines.push(`**Verdict:** ${verdict(status, failOn, gapCount)}`, '');
  }

  if (report) {
    lines.push('| Result | Count |', '|---|---|',
      `| Passed | ${passed} |`,
      `| Gap | ${gapCount} |`,
      `| Insufficient evidence | ${insufficient} |`, '');
    const windowDays = report.window?.days ?? env.windowDays;
    const events = Number.isFinite(report.trail?.eventCount) ? `, ${report.trail.eventCount} trail events` : '';
    lines.push(`Window: ${md(windowDays)} days, fail-on: ${md(failOn)}, exit code ${md(env.exitCode || 'n/a')}${events}`, '');
    if (gaps.length > 0) {
      lines.push('**Top gaps**', '');
      for (const g of gaps.slice(0, 5)) {
        const hint = firstSentence(g.evidence);
        const id = String(g.id ?? '').replace(/[^A-Za-z0-9._-]/g, '').slice(0, 40);
        lines.push(`- \`${id}\` (${md(g.severity, 20)}) **${md(g.title)}**${hint ? `: ${md(hint)}` : ''}`);
      }
      lines.push('');
    }
  } else if (ran && status === 'error') {
    lines.push('No report is shown because certify ended in an error. See the workflow logs.', '');
  } else if (ran) {
    lines.push('No JSON report was found in `.kya/certify/`. See the workflow logs.', '');
  }

  if (env.footer) {
    lines.push(`Hosted history: ${HOSTED_HISTORY_URL}`, '');
  }
  return lines.join('\n');
}

function main() {
  const footerInput = process.env.KYA_FOOTER ?? 'true';
  if (!['true', 'false', ''].includes(footerInput)) {
    console.log(`::warning title=kya certify::footer should be true or false (got an unsupported value). The footer is shown.`);
  }
  const env = {
    status: process.env.KYA_STATUS ?? '',
    exitCode: process.env.KYA_EXIT_CODE ?? '',
    failOn: process.env.KYA_FAIL_ON ?? '',
    windowDays: process.env.KYA_WINDOW_DAYS ?? '',
    footer: footerInput !== 'false',
  };
  const report = env.status === 'error' ? null : readReport(process.env.KYA_REPORT_PATH || '');
  const text = render(env, report);

  const target = process.env.GITHUB_STEP_SUMMARY;
  if (target) {
    fs.appendFileSync(target, `${text}\n`);
  } else {
    process.stdout.write(`${text}\n`);
  }
}

main();
