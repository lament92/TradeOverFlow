# Declaration of Generative AI Usage

This document is provided in accordance with academic integrity guidelines to outline the use of generative AI tools during the development of the TradeOverflow supplementary assessment project.

---

## 1. Generative AI Tool Used

**Tool**: Google Gemini

---

## 2. Manner of Use

Throughout the entire project lifecycle, the generative AI tool was employed as an interactive assistant. The development process was dialogic in nature—initiated by requirements derived from the assessment brief and followed by AI-generated recommendations and technical guidance.

Specific use cases include:

### Architecture Design  
The AI proposed an initial serverless architecture based on the stated non-functional requirements (availability, scalability, and maintainability). It recommended the use of **Amazon API Gateway**, **AWS Lambda**, **Amazon DynamoDB**, and **Amazon EventBridge**, along with justifications for each. Final architectural decisions were made after additional literature review and technical validation by myself.

### Code Initialization
The AI provided initial code scaffolding and implementation suggestions for various components of the project. These were subsequently modified, refined, and extended by me. AI-assisted code contributions include:

- Python source code for all **seven AWS Lambda functions**
- **Terraform configuration (main.tf)** for infrastructure-as-code and automated provisioning of AWS resources
- **k6 load testing script (k6-test.js)**, covering functional, performance, and failure scenarios
- **PlantUML code** for C4 and UML sequence diagrams included in the report
- **Shell deployment script (deploy.sh)** to automate build and deployment workflows

### Debugging and Troubleshooting  
The AI played a critical role in resolving numerous technical challenges encountered during local development and cloud deployment. This included step-by-step diagnostics and solutions related to:

- Local environment configuration (Docker networking, `npm`, `brew`, AWS CLI)
- Syntax and logic errors in Terraform code
- Integration issues across AWS services

### Documentation and Reporting  
The AI assisted in drafting the overall structural outline of the `report.md` document, which was later populated, revised, and finalized by me.

---

## 3. Extent of Use

The generative AI tool functioned as a key advisor and technical assistant. It contributed initial direction and scaffolding for architecture design and code implementation, and continuously supported problem-solving throughout the development cycle. My role consisted of interpreting the AI's suggestions, performing hands-on implementation, conducting testing, and completing final integration of all components. The final deliverables are the result of a human-led process informed by AI-assisted collaboration.