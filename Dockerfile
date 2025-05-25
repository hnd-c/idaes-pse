# Use Ubuntu 22.04 base image for better IDAES extensions compatibility
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH="/opt/conda/bin:$PATH"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gfortran \
    liblapack-dev \
    libblas-dev \
    libmetis-dev \
    wget \
    curl \
    git \
    coinor-libipopt1v5 \
    coinor-libipopt-dev \
    glpk-utils \
    coinor-cbc \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh && \
    /opt/conda/bin/conda clean -afy

# Create conda environment with Python 3.10
RUN conda create -n idaes python=3.10 -y && \
    echo "source activate idaes" >> ~/.bashrc

# Activate environment for subsequent commands
SHELL ["/bin/bash", "-c"]
ENV CONDA_DEFAULT_ENV=idaes
ENV PATH="/opt/conda/envs/idaes/bin:$PATH"

# Set working directory
WORKDIR /app

# Create necessary directories
RUN mkdir -p /app/.idaes /app/extensions

# Copy requirements and setup files
COPY requirements-dev.txt /app/
COPY setup.py /app/
COPY setup.cfg /app/

# Upgrade pip and install build tools
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Copy IDAES source code
COPY . /app/idaes-pse/
WORKDIR /app/idaes-pse

# Install IDAES with all optional dependencies
RUN pip install -e .[ui,grid,omlt,coolprop,testing]

# Install additional web server dependencies
RUN pip install \
    flask \
    flask-cors \
    fastapi \
    uvicorn \
    websockets \
    requests \
    psycopg2-binary \
    redis \
    networkx

# Install IDAES extensions using the standard method first
RUN idaes get-extensions --distro ubuntu2204 --verbose

# Add IDAES bin directory to PATH permanently
ENV PATH="/root/.idaes/bin:$PATH"

# Copy and run solver installation script
COPY install_solvers.py /app/
RUN python /app/install_solvers.py

# Set working directory back to /app
WORKDIR /app

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command
CMD ["python", "/app/docker/web_server.py"]