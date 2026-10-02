# ERPNext + India Compliance + our astrasun app, in one image.
# Build from the repo root:  docker build -f docker/Dockerfile -t astrasun:dev .
ARG ERPNEXT_VERSION=v15.121.6
FROM frappe/erpnext:${ERPNEXT_VERSION}

ARG INDIA_COMPLIANCE_BRANCH=version-15
USER frappe
WORKDIR /home/frappe/frappe-bench

# The base image keeps the built web files (desk, login, ...) in /home/frappe/frappe-bench/assets,
# outside the `sites` volume, and its entrypoint re-links sites/assets to that folder every time a
# container starts. Build the same way, so the bundles that India Compliance and our app add are
# merged into that folder and its assets.json. Without the link, `bench build` makes a fresh
# sites/assets that the entrypoint throws away at start, the browser never finds
# /india_compliance.bundle.js, and New Item fails with: Invalid "depends_on" expression.
RUN ln -s /home/frappe/frappe-bench/assets sites/assets

RUN bench get-app --branch ${INDIA_COMPLIANCE_BRANCH} india_compliance https://github.com/resilient-tech/india-compliance

COPY --chown=frappe:frappe apps/astrasun apps/astrasun
RUN env/bin/pip install --no-cache-dir -e apps/astrasun \
    && sed -i -e '$a\' sites/apps.txt \
    && (grep -qx astrasun sites/apps.txt || echo astrasun >> sites/apps.txt) \
    && bench build --app astrasun

# Leave sites/ as the base image does: no sites/assets in the image, the entrypoint adds the link.
RUN rm sites/assets
