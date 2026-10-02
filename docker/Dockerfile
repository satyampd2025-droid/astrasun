# ERPNext + India Compliance + our astrasun app, in one image.
# Build from the repo root:  docker build -f docker/Dockerfile -t astrasun:dev .
ARG ERPNEXT_VERSION=v15.121.6
FROM frappe/erpnext:${ERPNEXT_VERSION}

ARG INDIA_COMPLIANCE_BRANCH=version-15
USER frappe
WORKDIR /home/frappe/frappe-bench

RUN bench get-app --branch ${INDIA_COMPLIANCE_BRANCH} india_compliance https://github.com/resilient-tech/india-compliance

COPY --chown=frappe:frappe apps/astrasun apps/astrasun
RUN env/bin/pip install --no-cache-dir -e apps/astrasun \
    && sed -i -e '$a\' sites/apps.txt \
    && (grep -qx astrasun sites/apps.txt || echo astrasun >> sites/apps.txt) \
    && bench build --app astrasun
