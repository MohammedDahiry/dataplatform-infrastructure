# syntax=docker/dockerfile:1.6
#
# Spark + Iceberg + S3A + dbt-spark image used by Phase 4 SparkApplications.
# Built from the official Apache Spark image; we add Iceberg + Hadoop AWS jars
# and a Python venv with dbt-spark for dbt jobs triggered from Airflow.
#
# Tag convention: <ECR_URL>/spark-iceberg:3.5.0
# Official Docker Library image (docker.io/library/spark). The apache/spark repo does not publish this tag.
ARG SPARK_BASE=spark:3.5.0-scala2.12-java17-python3-ubuntu
FROM ${SPARK_BASE}

ARG ICEBERG_VERSION=1.4.2
ARG HADOOP_AWS_VERSION=3.3.4
ARG AWS_SDK_BUNDLE_VERSION=1.12.262
ARG SPARK_EXCEL_VERSION=3.5.0_0.20.3

USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates python3-pip \
 && rm -rf /var/lib/apt/lists/*

# Iceberg, Hadoop AWS, AWS SDK bundle, Spark-Excel jars (see spec §3.5, §4.3, §5.1).
RUN set -eux; \
    cd "${SPARK_HOME}/jars"; \
    curl -fsSLO "https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/${ICEBERG_VERSION}/iceberg-spark-runtime-3.5_2.12-${ICEBERG_VERSION}.jar"; \
    curl -fsSLO "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar"; \
    curl -fsSLO "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_BUNDLE_VERSION}/aws-java-sdk-bundle-${AWS_SDK_BUNDLE_VERSION}.jar"; \
    curl -fsSLO "https://repo1.maven.org/maven2/com/crealytics/spark-excel_2.12/${SPARK_EXCEL_VERSION}/spark-excel_2.12-${SPARK_EXCEL_VERSION}.jar"

COPY requirements.txt /tmp/requirements.txt
# Base image ships an old pip that does not support --break-system-packages; upgrade first.
RUN python3 -m pip install --upgrade "pip>=23.2" setuptools wheel \
 && python3 -m pip install --no-cache-dir --break-system-packages -r /tmp/requirements.txt \
 && rm /tmp/requirements.txt

# Embedded PySpark jobs (avoids uploading them to MinIO; image is the unit of release).
COPY jobs /opt/jobs
RUN chmod -R a+rX /opt/jobs

# dbt project + profiles template (rendered at runtime from a ConfigMap or Secret).
COPY dbt /opt/dbt
RUN chmod -R a+rX /opt/dbt

ENV PYTHONPATH=/opt/jobs:${PYTHONPATH:-}

USER ${spark_uid:-185}
