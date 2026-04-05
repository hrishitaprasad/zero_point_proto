const express = require("express");

const app = express();
app.use(express.json());

const VT_API_KEY = process.env.VT_API_KEY || "PUT_YOUR_VT_KEY_HERE";
const PORT = 4040;

function classify(detected) {
  if (detected === 0) return "safe";
  if (detected <= 3) return "risky_but_can_try";
  return "risky";
}

function summaryFromLabel(label, detected, total) {
  if (label === "safe") return `Safe - ${detected}/${total}`;
  if (label === "risky_but_can_try") {
    return `Risky but can try - ${detected}/${total}`;
  }
  return `Risky - ${detected}/${total}`;
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

app.post("/scan-url", async (req, res) => {
  try {
    const { url } = req.body ?? {};

    if (!url || typeof url !== "string") {
      return res.status(400).json({ error: "Missing or invalid url" });
    }

    const submitResp = await fetch("https://www.virustotal.com/api/v3/urls", {
      method: "POST",
      headers: {
        "x-apikey": VT_API_KEY,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ url }),
    });

    const submitJson = await submitResp.json();
    const analysisId = submitJson?.data?.id;

    if (!analysisId) {
      return res.status(500).json({
        error: "Failed to get analysis ID",
        raw: submitJson,
      });
    }

    let analysisJson = null;
    let stats = null;

    for (let i = 0; i < 6; i++) {
      await sleep(2500);

      const analysisResp = await fetch(
        `https://www.virustotal.com/api/v3/analyses/${analysisId}`,
        {
          headers: {
            "x-apikey": VT_API_KEY,
          },
        }
      );

      analysisJson = await analysisResp.json();
      const status = analysisJson?.data?.attributes?.status;
      stats = analysisJson?.data?.attributes?.stats;

      if (status === "completed" && stats) {
        break;
      }
    }

    if (!stats) {
      return res.status(500).json({
        error: "Analysis did not complete in time",
        raw: analysisJson,
      });
    }

    const malicious = Number(stats.malicious ?? 0);
    const suspicious = Number(stats.suspicious ?? 0);

    const total = Object.values(stats).reduce((sum, v) => {
      return sum + Number(v ?? 0);
    }, 0);

    const detected = malicious + suspicious;
    const label = classify(detected);
    const summary = summaryFromLabel(label, detected, total);

    return res.json({
      url,
      label,
      detected,
      total,
      summary,
      stats,
    });
  } catch (err) {
    return res.status(500).json({
      error: err.message || "Unknown server error",
    });
  }
});

app.listen(PORT, () => {
  console.log(`VirusTotal link scan backend running on port ${PORT}`);
});