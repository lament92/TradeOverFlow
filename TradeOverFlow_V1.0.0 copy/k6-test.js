import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
// ---导入报告生成器 ---
import { htmlReport } from "https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.1/index.js";


// 从命令行环境变量中读取 API URL
const API_BASE_URL = __ENV.API_URL;

export const options = {
  scenarios: {
    full_trade_lifecycle: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 20 },
        { duration: '10s', target: 0 },
      ],
      exec: 'fullTradeLifecycle',
    },
    update_prices: {
      executor: 'constant-vus',
      vus: 5,
      duration: '1m30s',
      startTime: '30s',
      exec: 'updatePrices',
    },
    error_conditions: {
        executor: 'per-vu-iterations',
        vus: 3,
        iterations: 5,
        startTime: '40s',
        exec: 'errorConditions',
    }
  },
  thresholds: {
    'http_req_failed': ['rate<0.01'],
    'http_req_duration': ['p(95)<1500'],
  },
};

// --- 测试函数定义 ---

export function fullTradeLifecycle() {
  if (!API_BASE_URL) return;
  const headers = { 'Content-Type': 'application/json' };
  const itemType = `trade-item-${Math.floor(__VU / 10)}`;
  const sellerId = uuidv4();
  const buyerId = uuidv4();
  let itemId = null;
  let bidId = null;

  group('Lifecycle - 1. List & Bid', function () {
    const sellPrice = 50;
    const bidPrice = 55;

    const listItemPayload = JSON.stringify({ item_type: itemType, seller_id: sellerId, min_price: sellPrice });
    const listRes = http.post(`${API_BASE_URL}/items`, listItemPayload, { headers });
    if (check(listRes, { 'Lifecycle: POST /items status 201': (r) => r.status === 201 })) {
        itemId = listRes.json('item_id');
    }

    const submitBidPayload = JSON.stringify({ item_type: itemType, buyer_id: buyerId, max_price: bidPrice });
    const bidRes = http.post(`${API_BASE_URL}/bids`, submitBidPayload, { headers });
    if (check(bidRes, { 'Lifecycle: POST /bids status 201': (r) => r.status === 201 })) {
        bidId = bidRes.json('bid_id');
    }
  });

  group('Lifecycle - 2. Wait for backend', function() {
    sleep(65);
  });

  group('Lifecycle - 3. Verify Outcome', function () {
    if (itemId) {
      const itemStatusRes = http.get(`${API_BASE_URL}/items/${itemId}/status`);
      check(itemStatusRes, { 'Lifecycle: Item status is SOLD': (r) => r.status === 200 && r.json('status') === 'SOLD' });
    }
    if (bidId) {
      const bidStatusRes = http.get(`${API_BASE_URL}/bids/${bidId}/status`);
      check(bidStatusRes, { 'Lifecycle: Bid status is SUCCESSFUL': (r) => r.status === 200 && r.json('status') === 'SUCCESSFUL' });
    }
  });
}

export function updatePrices() {
    if (!API_BASE_URL) return;
    const headers = { 'Content-Type': 'application/json' };
    const itemType = 'price-update-item';
    const sellerId = uuidv4();
    let itemId = null;

    const listItemPayload = JSON.stringify({ item_type: itemType, seller_id: sellerId, min_price: 100 });
    const listRes = http.post(`${API_BASE_URL}/items`, listItemPayload, { headers });
    if (listRes.status === 201) {
        itemId = listRes.json('item_id');
    }
    sleep(1);

    if (itemId) {
        group('Update Price - 1. Update existing item price', function() {
            const updatePayload = JSON.stringify({ new_price: 110 });
            const updateRes = http.put(`${API_BASE_URL}/items/${itemId}/price`, updatePayload, { headers });
            check(updateRes, { 'Update Price: PUT /items/{itemId}/price status 200': (r) => r.status === 200 });
        });
    }
}

export function errorConditions() {
    if (!API_BASE_URL) return;
    const headers = { 'Content-Type': 'application/json' };
    const itemType = 'error-test-item';
    const sellerId = uuidv4();
    const buyerId = uuidv4();
    let itemId = null;

    const listItemPayload = JSON.stringify({ item_type: itemType, seller_id: sellerId, min_price: 20 });
    const listRes = http.post(`${API_BASE_URL}/items`, listItemPayload, { headers });
    if (listRes.status === 201) itemId = listRes.json('item_id');
    
    const submitBidPayload = JSON.stringify({ item_type: itemType, buyer_id: buyerId, max_price: 25 });
    http.post(`${API_BASE_URL}/bids`, submitBidPayload, { headers });

    sleep(65);

    if (itemId) {
        group('Error Condition - 1. Try to update price of a SOLD item', function() {
            const updatePayload = JSON.stringify({ new_price: 30 });
            const updateRes = http.put(`${API_BASE_URL}/items/${itemId}/price`, updatePayload, { headers });
            check(updateRes, { 'Error: PUT on sold item returns 409': (r) => r.status === 409 });
        });
    }
}

// ---k6 在测试结束时调用这个函数 ---
export function handleSummary(data) {
  return {
    "test-result.html": htmlReport(data), // 生成 HTML 报告
    stdout: textSummary(data, { indent: " ", enableColors: true }), // 在控制台显示文本报告
  };
}
