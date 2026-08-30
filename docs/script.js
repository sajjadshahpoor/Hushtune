const REPO = "sajjadshahpoor/Hushtune";
const API_URL = `https://api.github.com/repos/${REPO}/releases`;

const versionBadge = document.getElementById("version-badge");
const downloadBtn = document.getElementById("download-btn");
const releasesList = document.getElementById("releases-list");

function formatDate(iso) {
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

function renderNoReleases() {
  versionBadge.textContent = "No releases yet — build from source";
  releasesList.innerHTML = `<p class="releases-empty">No releases have been published yet. Check back soon, or build the app yourself from the source above.</p>`;
}

function renderReleases(releases) {
  if (!releases || releases.length === 0) {
    renderNoReleases();
    return;
  }

  const latest = releases[0];
  versionBadge.textContent = `Latest version: ${latest.tag_name}`;

  const latestAsset = latest.assets && latest.assets.find(a => a.name.endsWith(".ipa"));
  downloadBtn.href = latestAsset ? latestAsset.browser_download_url : latest.html_url;

  releasesList.innerHTML = "";
  releases.slice(0, 5).forEach(release => {
    const asset = release.assets && release.assets.find(a => a.name.endsWith(".ipa"));
    const link = document.createElement("a");
    link.className = "release-item";
    link.href = asset ? asset.browser_download_url : release.html_url;
    link.target = "_blank";
    link.rel = "noopener";
    link.innerHTML = `
      <div>
        <div class="tag">${release.tag_name}${release.name && release.name !== release.tag_name ? " — " + release.name : ""}</div>
        <div class="date">${formatDate(release.published_at)}</div>
      </div>
      <div class="arrow">${asset ? "Download →" : "View →"}</div>
    `;
    releasesList.appendChild(link);
  });
}

fetch(API_URL)
  .then(res => {
    if (!res.ok) throw new Error(`GitHub API returned ${res.status}`);
    return res.json();
  })
  .then(renderReleases)
  .catch(() => {
    renderNoReleases();
  });
