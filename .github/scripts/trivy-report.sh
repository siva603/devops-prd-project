#!/usr/bin/env bash
# Trivy report helper used by .github/workflows/ci.yml
#
#   trivy-report.sh count  <report.json>   number of HIGH/CRITICAL findings (vulnerabilities + secrets)
#   trivy-report.sh detail <report.json>   one line per finding
#   trivy-report.sh email  <reports-dir>   build the summary and send it by e-mail
set -euo pipefail

count_findings() {
  jq '[.Results[]? | (.Vulnerabilities[]?, .Secrets[]?)] | length' "$1"
}

count_severity() {
  jq --arg severity "$2" \
    '[.Results[]? | (.Vulnerabilities[]?, .Secrets[]?) | select(.Severity == $severity)] | length' "$1"
}

detail_findings() {
  jq -r '
    .Results[]? | .Target as $target |
    ( .Vulnerabilities[]? |
      "  [\(.Severity)] \(.VulnerabilityID)  \(.PkgName) \(.InstalledVersion) -> fix: \(.FixedVersion // "none")  | \(.Title // "" | .[0:80])  | \($target)" ),
    ( .Secrets[]? |
      "  [\(.Severity)] SECRET \(.RuleID): \(.Title // "")  | \($target) line \(.StartLine)" )
  ' "$1" | sort
}

send_email() {
  local dir="$1"

  if [ -z "${SMTP_HOST:-}" ] || [ -z "${SMTP_USERNAME:-}" ] || [ -z "${SMTP_PASSWORD:-}" ] || [ -z "${MAIL_TO:-}" ]; then
    echo "E-mail settings (SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD, MAIL_TO) are not set. Skipping e-mail."
    return 0
  fi

  local port="${SMTP_PORT:-465}"
  local from="${MAIL_FROM:-$SMTP_USERNAME}"
  local scheme="smtps"
  if [ "$port" != "465" ]; then
    scheme="smtp"
  fi

  # Reports we expect: the filesystem scan and one scan per image
  local names="trivy-fs"
  local service
  for service in ${SERVICES:-}; do
    names="$names trivy-image-$service"
  done

  local summary="" details=""
  local total_all=0 critical_all=0 high_all=0 missing=0
  local name file total critical high

  for name in $names; do
    file="$dir/$name.json"

    if [ ! -f "$file" ]; then
      summary+="$(printf '  %-34s NO REPORT (the scan did not run or the job failed)' "$name")"$'\n'
      missing=$((missing + 1))
      continue
    fi

    if ! total=$(count_findings "$file" 2>/dev/null); then
      summary+="$(printf '  %-34s REPORT COULD NOT BE READ' "$name")"$'\n'
      missing=$((missing + 1))
      continue
    fi

    critical=$(count_severity "$file" CRITICAL)
    high=$(count_severity "$file" HIGH)
    total_all=$((total_all + total))
    critical_all=$((critical_all + critical))
    high_all=$((high_all + high))

    summary+="$(printf '  %-34s total %-4s critical %-4s high %-4s' "$name" "$total" "$critical" "$high")"$'\n'

    if [ "$total" -gt 0 ]; then
      details+="== $name =="$'\n'"$(detail_findings "$file")"$'\n\n'
    fi
  done

  # Subject and headline
  local subject headline
  if [ "$total_all" -eq 0 ] && [ "$missing" -eq 0 ]; then
    subject="[CI] Trivy all clear - 0 vulnerabilities - ${REPO:-repo} (${BRANCH:-branch})"
    headline="GOOD NEWS: Trivy found no fixable HIGH or CRITICAL vulnerabilities and no secrets. No action needed."
  elif [ "$total_all" -gt 0 ]; then
    subject="[CI] Trivy ACTION NEEDED - $total_all findings ($critical_all critical, $high_all high) - ${REPO:-repo} (${BRANCH:-branch})"
    headline="ACTION NEEDED: Trivy found $total_all fixable HIGH/CRITICAL issues ($critical_all critical, $high_all high)."
    if [ "$missing" -gt 0 ]; then
      headline="$headline Also, $missing report(s) are missing, see the summary."
    fi
  else
    subject="[CI] Trivy reports missing - check the pipeline - ${REPO:-repo} (${BRANCH:-branch})"
    headline="CHECK THE PIPELINE: $missing Trivy report(s) were not created, so those scans have no result."
  fi

  local gate_text="OFF (report only: images are still pushed to ECR)"
  if [ "${GATE:-0}" = "1" ]; then
    gate_text="ON (images with findings are NOT pushed to ECR)"
  fi

  # Body
  local body_file mail_file
  body_file=$(mktemp)
  mail_file=$(mktemp)

  {
    echo "$headline"
    echo
    echo "Repository    : ${REPO:-}"
    echo "Branch        : ${BRANCH:-}"
    echo "Commit        : ${SHA:-}"
    echo "Started by    : ${ACTOR:-}"
    echo "Pipeline run  : ${RUN_URL:-}"
    echo "Security gate : $gate_text"
    echo
    echo "SUMMARY (fixable HIGH and CRITICAL findings per scan)"
    printf '%s' "$summary"
    echo

    if [ "$total_all" -gt 0 ]; then
      echo "IMMEDIATE ACTION"
      echo "  1. Read DETAILS below. Each line shows the package, the installed version and the fixed version."
      echo "  2. OS packages (alpine, libssl, libcrypto, ...): add 'apk upgrade --no-cache' to the Dockerfile and rebuild."
      echo "  3. Packages under usr/local/lib/node_modules/npm: this is npm inside the base image."
      echo "     Remove npm in the final Docker stage, the running service does not need it."
      echo "  4. Packages under app/node_modules or package-lock.json: update the package to the fixed version and rebuild."
      echo "  5. SECRET findings: remove the secret from the repository and change (rotate) it immediately."
      echo
      echo "DETAILS"
      printf '%s' "$details"
    elif [ "$missing" -eq 0 ]; then
      echo "Nothing to fix. Every scan finished and every report is clean."
      echo
    fi

    echo "The full JSON reports are saved under Artifacts at the bottom of the pipeline run page."
  } > "$body_file"

  # Mail message (SMTP needs CRLF line endings)
  {
    echo "From: Trivy CI <$from>"
    echo "To: $MAIL_TO"
    echo "Subject: $subject"
    echo "Date: $(date -R)"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo "Content-Transfer-Encoding: 8bit"
    echo
    cat "$body_file"
  } | sed 's/$/\r/' > "$mail_file"

  # More than one recipient can be written as: a@x.com,b@y.com
  local recipients rcpt
  local rcpt_args=()
  IFS=',' read -ra recipients <<< "$MAIL_TO"
  for rcpt in "${recipients[@]}"; do
    rcpt=$(echo "$rcpt" | xargs)
    rcpt_args+=(--mail-rcpt "$rcpt")
  done

  echo "Sending e-mail: $subject"

  curl --silent --show-error --fail --ssl-reqd \
    --url "${scheme}://${SMTP_HOST}:${port}" \
    --user "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
    --mail-from "$from" \
    "${rcpt_args[@]}" \
    --upload-file "$mail_file"

  echo "E-mail sent to $MAIL_TO"
}

case "${1:-}" in
  count)  count_findings "${2:?report file is required}" ;;
  detail) detail_findings "${2:?report file is required}" ;;
  email)  send_email "${2:?reports folder is required}" ;;
  *)
    echo "Usage: trivy-report.sh count|detail <report.json>  or  trivy-report.sh email <reports-dir>" >&2
    exit 1
    ;;
esac