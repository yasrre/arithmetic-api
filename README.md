# Python Arithmetic API with DevSecOps CI/CD Pipeline

This project demonstrates the implementation of a DevSecOps pipeline for a simple Python Flask Arithmetic API using Docker, Jenkins, and various open-source security tools.

## Features ✨

* **Simple Arithmetic API:** Performs Addition, Subtraction, Multiplication, and Division via RESTful endpoints.
* **Containerized:** Built and deployed using Docker and Docker Compose for consistency.
* **Automated CI/CD:** Jenkins pipeline automates testing, security scanning, image building, pushing to Docker Hub, and deployment.
* **Integrated Security:**
    * **SAST:** Static Application Security Testing using **Bandit**.
    * **SCA:** Software Composition Analysis using **Safety**.
    * **Image Scanning:** Container image vulnerability scanning using **Trivy**.
* **Unit Tested:** Code reliability verified using **Pytest**.

## DevSecOps Workflow ⚙️

The `Jenkinsfile` defines the automated pipeline with the following stages:

1.  **Checkout Code:** Clones the latest code from the `main` branch.
2.  **Security & Tests:**
    * Installs dependencies and security tools (`Bandit`, `Safety`, `Pytest`) inside a temporary Python Docker agent.
    * Runs **Bandit** for SAST.
    * Runs **Safety** for SCA.
    * Runs **Pytest** unit tests.
3.  **Build & Image Scan (Trivy):**
    * Builds the final Docker image using the host's Docker CLI.
    * Scans the built image with **Trivy** for High/Critical vulnerabilities (pipeline fails if found).
    * Tags the image with the build number and `:latest`.
4.  **Publish Image:** Pushes the tagged images to Docker Hub (`yassineokr/arithmetic-api`).
5.  **Deploy Application:** Deploys the application using `docker-compose up -d`.

## Security Improvements Achieved 🛡️

* **SAST:** Identified and fixed a Medium severity issue (B104 - bind to all interfaces) reported by Bandit.
* **Image Hardening:** Reduced OS vulnerabilities from **125+ CVEs** (found in the initial Debian 10 base image) to **0 High/Critical CVEs** by switching to `python:3.9-alpine` and upgrading `pip`, as verified by Trivy.
* **SCA:** Confirmed application dependencies are free from known vulnerabilities using Safety.

## Setup and Usage 🚀

### Prerequisites

* Docker & Docker Compose
* Python 3.x
* Git
* Trivy (Optional, for local scanning)

### Running Locally

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/yasrre/arithmetic-api.git](https://github.com/yasrre/arithmetic-api.git)
    cd arithmetic-api
    ```

2.  **Build and Run with Docker Compose:**
    ```bash
    docker-compose up --build -d
    ```
    The API will be available at `http://localhost:8000`.

### Running the CI/CD Pipeline (Requires Jenkins Setup)

1.  Set up Jenkins with necessary plugins (Git, Docker Pipeline).
2.  Configure credentials for GitHub (`github-scm-credential`) and Docker Hub (`docker-hub-credentials`).
3.  Create a new Pipeline job pointing to this repository and the `Jenkinsfile`.
4.  Ensure Jenkins has access to the host's Docker socket (`/var/run/docker.sock`) and the `trivy` command is available.
5.  Trigger the build.

## Proposed Performance Monitoring 📊

For production environments, performance should be tracked using:

* **Prometheus:** For scraping application metrics (latency, error rates).
* **Grafana:** For visualizing metrics on dashboards.
* **Instrumentation:** Using a library like `prometheus_flask_exporter` within the Flask app.
