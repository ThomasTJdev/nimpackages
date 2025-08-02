import std/[
  cgi,
  envvars,
  strutils,
  sequtils,
  times
]

import
  ./packages

const css = """
  * {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
  }

  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
    line-height: 1.6;
    color: #333;
    background: linear-gradient(135deg, #1f3ab4 0%, #001d56 100%);
    min-height: 100vh;
  }

  .container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
  }

  .header {
    text-align: center;
    margin-bottom: 40px;
    color: white;
  }

  .header h1 {
    font-size: 3rem;
    margin-bottom: 10px;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
  }

  .header a {
    text-decoration: none;
    color: inherit;
  }

  .header p a {
    color: inherit;
    text-decoration: underline;
  }

  .header p {
    font-size: 1.2rem;
    opacity: 0.9;
  }

  .footer {
    text-align: center;
    padding: 20px;
    color: #666;
    font-size: 0.8rem;
  }

  .footer a {
    color: inherit;
  }

  .search-container {
    background: white;
    border-radius: 15px;
    padding: 30px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
    margin-bottom: 30px;
  }

  .search-form {
    display: flex;
    gap: 15px;
    margin-bottom: 20px;
  }

  .search-input {
    flex: 1;
    padding: 15px 20px;
    border: 2px solid #e1e5e9;
    border-radius: 10px;
    font-size: 1.1rem;
    transition: border-color 0.3s ease;
  }

  .search-input:focus {
    outline: none;
    border-color: #1f3ab4;
  }

  .search-button {
    padding: 15px 30px;
    background: linear-gradient(135deg, #1f3ab4 0%, #001d56 100%);
    color: white;
    border: none;
    border-radius: 10px;
    font-size: 1.1rem;
    cursor: pointer;
    transition: transform 0.2s ease;
  }

  .search-button:hover {
    transform: translateY(-2px);
  }

  .stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 20px;
    margin-top: 30px;
  }

  .stat-card {
    background: white;
    padding: 20px;
    border-radius: 10px;
    text-align: center;
    box-shadow: 0 5px 15px rgba(0,0,0,0.1);
  }

  .stat-number {
    font-size: 2rem;
    font-weight: bold;
    color: #1f3ab4;
    margin-bottom: 5px;
  }

  .stat-label {
    color: #666;
    font-size: 0.9rem;
  }

  .results-container {
    background: white;
    border-radius: 15px;
    padding: 30px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
  }

  .results-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    padding-bottom: 15px;
    border-bottom: 2px solid #f0f0f0;
  }

  .results-count {
    font-size: 1.1rem;
    color: #666;
  }

  .back-link {
    color: #1f3ab4;
    text-decoration: none;
    font-weight: 500;
  }

  .back-link:hover {
    text-decoration: underline;
  }

  .package-card {
    border: 1px solid #e1e5e9;
    border-radius: 10px;
    padding: 20px;
    margin-bottom: 15px;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
  }

  .package-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(0,0,0,0.1);
  }

  .package-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 10px;
  }

  .package-name {
    font-size: 1.3rem;
    font-weight: bold;
    color: #333;
    text-decoration: none;
  }

  .package-name:hover {
    color: #1f3ab4;
  }

  .package-score {
    background: #1f3ab4;
    color: white;
    padding: 4px 8px;
    border-radius: 5px;
    font-size: 0.8rem;
    font-weight: bold;
  }

  .package-description {
    color: #666;
    margin-bottom: 10px;
    line-height: 1.5;
  }

  .package-meta {
    display: flex;
    gap: 15px;
    font-size: 0.9rem;
    color: #888;
  }

  .package-tags {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-top: 10px;
  }

  .tag {
    background: #f0f0f0;
    color: #666;
    padding: 4px 8px;
    border-radius: 15px;
    font-size: 0.8rem;
  }

  .package-details {
    background: white;
    border-radius: 15px;
    padding: 30px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
  }

  .detail-header {
    margin-bottom: 30px;
    padding-bottom: 20px;
    border-bottom: 2px solid #f0f0f0;
  }

  .detail-name {
    font-size: 2.5rem;
    font-weight: bold;
    color: #333;
    margin-bottom: 10px;
  }

  .detail-description {
    font-size: 1.2rem;
    color: #666;
    margin-bottom: 20px;
  }

  .detail-meta {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 20px;
    margin-bottom: 30px;
  }

  .meta-item {
    background: #f8f9fa;
    padding: 15px;
    border-radius: 8px;
  }

  .meta-label {
    font-weight: bold;
    color: #333;
    margin-bottom: 5px;
  }

  .meta-value {
    color: #666;
  }

  .detail-tags {
    margin-top: 20px;
  }

  .detail-tags h3 {
    margin-bottom: 10px;
    color: #333;
  }

  .no-results {
    text-align: center;
    padding: 40px;
    color: #666;
  }

  .no-results h3 {
    margin-bottom: 10px;
    color: #333;
  }

  .loading {
    text-align: center;
    padding: 40px;
    color: #666;
  }

  @media (max-width: 768px) {
    .container {
      padding: 10px;
    }

    .header h1 {
      font-size: 2rem;
    }

    .search-form {
      flex-direction: column;
    }

    .package-header {
      flex-direction: column;
      gap: 10px;
    }

    .package-meta {
      flex-direction: column;
      gap: 5px;
    }
  }
"""

const js = """
  document.addEventListener('DOMContentLoaded', function() {
    const searchForm = document.getElementById('search-form');
    const searchInput = document.getElementById('search-input');

    if (searchForm) {
      searchForm.addEventListener('submit', function(e) {
        e.preventDefault();
        const query = searchInput.value.trim();
        if (query) {
          window.location.href = '/search?q=' + encodeURIComponent(query);
        }
      });
    }

    // Auto-focus search input
    if (searchInput) {
      searchInput.focus();
    }
  });
"""

proc indexPackagesAll*(): string =
  let stats = getPackageCount()
  let lastUpdated = getLastUpdated().fromUnix()

  result = """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    """ & getEnv("HTML_HEAD") & """
    <title>Nim Packages - Discover Nim Libraries</title>
    <style>""" & css & """</style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <a href="/">
          <div style="display: flex; justify-content: center; align-items: center; gap: 20px; ">
            <div class="stat-number" style="position: relative;">
              <span style="position: absolute; top: -8px; left: 50%; transform: translateX(-50%); font-size: 0.8em;">👑</span>
              <span style="margin-top: 8px; display: inline-block;">📦</span>
            </div>
            <h1>Nim Packages</h1>
          </div>
        </a>
        <p>Discover and explore Nim libraries and packages</p>
        <p>Learn more about <a href="https://nim-lang.org" target="_blank">Nim here</a> and <a href="https://nim-lang.github.io/nimble/" target="_blank">Nimble here</a></p>
      </div>

      <div class="search-container">
        <form class="search-form" id="search-form" action="/search" method="GET">
          <input
            type="text"
            name="q"
            id="search-input"
            class="search-input"
            placeholder="Search packages (e.g., 'clap', 'http', 'json')..."
            autocomplete="off"
          >
          <button type="submit" class="search-button">Search</button>
        </form>

        <div class="stats">
          <div class="stat-card">
            <div class="stat-number">""" & $stats & """</div>
            <div class="stat-label">Total Packages</div>
          </div>
          <div class="stat-card">
            <div class="stat-number">""" & lastUpdated.format("yyyy-MM-dd HH:mm:ss") & """</div>
            <div class="stat-label">Last Updated</div>
          </div>
          <div class="stat-card">
            <div class="stat-label" style="text-align: left;">Install with Nimble</div>
            <div style="margin-top: 10px; font-family: 'Monaco', 'Menlo', monospace; font-size: 0.8rem; color: #666; text-align: left;">
              <div style="margin-bottom: 5px;">$ nimble install &lt;pkg&gt;</div>
              <div>$ nimble install --depsOnly</div>
            </div>
          </div>
        </div>
      </div>

      <div class="results-container">
        <div class="results-header">
          <h2>Packages</h2>
        </div>
        <p style="text-align: center; color: #666; padding: 40px;">
          Use the search bar above to discover Nim packages.
          <br>Try searching for: <strong>clap</strong>, <strong>http</strong>, <strong>json</strong>, or <strong>async</strong>
        </p>
      </div>
    </div>
    <div class="footer">
      Copyright <a href="https://github.com/ThomasTJdev/nimpackages">Thomas T. Jarloev (TTJ)</a><br>Hosted by <a href="https://cxplanner.com">CxPlanner</a><br>We love <a href="https://nim-lang.org">Nim</a>
    </div>
    <script>""" & js & """</script>
  </body>
  </html>
  """

proc indexPackagesSearch*(query: string): string =
  let searchResults = searchPackagesWithScore(query)

  var resultsHtml = ""
  if searchResults.len > 0:
    for result in searchResults:
      let package = result.package
      let tagsHtml = package.tags.mapIt("""<span class="tag">""" & it & """</span>""").join("")

      # Should we open and display info? That annoys me. I just want the repo directly.
      # <a href="/package/""" & package.name & """" class="package-name">""" & package.name & """</a>
      resultsHtml &= """
        <div class="package-card">
          <div class="package-header">
            <a href="""" & package.url & """" target="_blank">""" & package.name & """</a>
            <span class="package-score">""" & $result.score & """</span>
          </div>
          <div class="package-description">""" & package.description & """</div>
          <div class="package-meta">
            <span>📦 """ & package.mmethod & """</span>
            <span>📄 """ & package.license & """</span>
            <span>🔗 <a href="""" & package.url & """" target="_blank">Repository</a></span>
            <span>🔗 <a href="""" & package.web & """" target="_blank">Website</a></span>
          </div>
          <div class="package-tags">""" & tagsHtml & """</div>
        </div>
      """
  else:
    resultsHtml = """
      <div class="no-results">
        <h3>No packages found</h3>
        <p>Try a different search term or browse all packages.</p>
      </div>
    """

  result = """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    """ & getEnv("HTML_HEAD") & """
    <title>Search Results - Nim Packages</title>
    <style>""" & css & """</style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <a href="/">
          <div style="display: flex; justify-content: center; align-items: center; gap: 20px; ">
            <div class="stat-number" style="position: relative;">
              <span style="position: absolute; top: -8px; left: 50%; transform: translateX(-50%); font-size: 0.8em;">👑</span>
              <span style="margin-top: 8px; display: inline-block;">📦</span>
            </div>
            <h1>Nim Packages</h1>
          </div>
        </a>
        <p>Search Results</p>
      </div>

      <div class="search-container">
        <form class="search-form" id="search-form" action="/search" method="GET">
          <input
            type="text"
            name="q"
            id="search-input"
            class="search-input"
            placeholder="Search packages..."
            value="""" & query.xmlEncode & """"
            autocomplete="off"
          >
          <button type="submit" class="search-button">Search</button>
        </form>
      </div>

      <div class="results-container">
        <div class="results-header">
          <div class="results-count">""" & $searchResults.len & """ result""" & (if searchResults.len == 1: "" else: "s") & """ for '""" & query.xmlEncode & """'</div>
          <a href="/" class="back-link">← Back to Home</a>
        </div>
        """ & resultsHtml & """
      </div>
    </div>
    <div class="footer">
      Copyright <a href="https://github.com/ThomasTJdev/nimpackages">Thomas T. Jarloev (TTJ)</a><br>Hosted by <a href="https://cxplanner.com">CxPlanner</a><br>We love <a href="https://nim-lang.org">Nim</a>
    </div>
    <script>""" & js & """</script>
  </body>
  </html>
  """

proc packageDetails*(name: string): string =
  let package = getPackage(name)

  if package.name.len == 0:
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      """ & getEnv("HTML_HEAD") & """
      <title>Package Not Found - Nim Packages</title>
      <style>""" & css & """</style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <a href="/">
            <div style="display: flex; justify-content: center; align-items: center; gap: 20px; ">
              <div class="stat-number" style="position: relative;">
                <span style="position: absolute; top: -8px; left: 50%; transform: translateX(-50%); font-size: 0.8em;">👑</span>
                <span style="margin-top: 8px; display: inline-block;">📦</span>
              </div>
              <h1>Nim Packages</h1>
            </div>
          </a>
          <p>Package Not Found</p>
        </div>
        <div class="package-details">
          <div class="no-results">
            <h3>Package '""" & name.xmlEncode & """' not found</h3>
            <p>The package you're looking for doesn't exist or has been removed.</p>
            <a href="/" class="back-link">← Back to Home</a>
          </div>
        </div>
      </div>
      <div class="footer">
        Copyright <a href="https://github.com/ThomasTJdev/nimpackages">Thomas T. Jarloev (TTJ)</a><br>Hosted by <a href="https://cxplanner.com">CxPlanner</a><br>We love <a href="https://nim-lang.org">Nim</a>
      </div>
    </body>
    </html>
    """

  let tagsHtml = package.tags.mapIt("""<span class="tag">""" & it & """</span>""").join("")

  result = """
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    """ & getEnv("HTML_HEAD") & """
    <title>""" & package.name.xmlEncode & """ - Nim Packages</title>
    <style>""" & css & """</style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <a href="/">
          <div style="display: flex; justify-content: center; align-items: center; gap: 20px; ">
            <div class="stat-number" style="position: relative;">
              <span style="position: absolute; top: -8px; left: 50%; transform: translateX(-50%); font-size: 0.8em;">👑</span>
              <span style="margin-top: 8px; display: inline-block;">📦</span>
            </div>
            <h1>Nim Packages</h1>
          </div>
        </a>
        <p>Package Details</p>
      </div>

      <div class="package-details">
        <div class="detail-header">
          <div class="detail-name">""" & package.name.xmlEncode & """</div>
          <div class="detail-description">""" & package.description.xmlEncode & """</div>
        </div>

        <div class="detail-meta">
          <div class="meta-item">
            <div class="meta-label">Installation Method</div>
            <div class="meta-value">""" & package.mmethod.xmlEncode & """</div>
          </div>
          <div class="meta-item">
            <div class="meta-label">License</div>
            <div class="meta-value">""" & package.license.xmlEncode & """</div>
          </div>
          <div class="meta-item">
            <div class="meta-label">Repository</div>
            <div class="meta-value"><a href="""" & package.url.xmlEncode & """" target="_blank">""" & package.url.xmlEncode & """</a></div>
          </div>
          <div class="meta-item">
            <div class="meta-label">Website</div>
            <div class="meta-value"><a href="""" & package.web.xmlEncode & """" target="_blank">""" & package.web.xmlEncode & """</a></div>
          </div>
        </div>

        <div class="detail-tags">
          <h3>Tags</h3>
          <div class="package-tags">""" & tagsHtml & """</div>
        </div>

        <div style="margin-top: 30px; text-align: center;">
          <a href="/" class="back-link">← Back to Home</a>
        </div>
      </div>
    </div>
    <div class="footer">
      Copyright <a href="https://github.com/ThomasTJdev/nimpackages">Thomas T. Jarloev (TTJ)</a><br>Hosted by <a href="https://cxplanner.com">CxPlanner</a><br>We love <a href="https://nim-lang.org">Nim</a>
    </div>
  </body>
  </html>
  """
    </div>
  </body>
  </html>
  """