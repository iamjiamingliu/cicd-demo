"use client";

import {
  useState,
  type ChangeEvent,
  type FormEvent,
  type MouseEvent,
} from "react";

type HttpMethod = "GET" | "POST" | "PUT" | "DELETE";

const dropdownOptions: HttpMethod[] = ["GET", "POST", "PUT", "DELETE"];

export default function Body() {
  const [route, setRoute] = useState("");
  const [message, setMessage] = useState("");
  const [response, setResponse] = useState("");
  const [method, setMethod] = useState<HttpMethod>("GET");
  const [port, setPort] = useState("8080");

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!route.trim()) {
      return;
    }

    try {
      const requestOptions: RequestInit = { method };
      if (method !== "GET") {
        requestOptions.body = message;
      }

      const baseUrl =
        process.env.NEXT_PUBLIC_API_URL ?? `http://localhost:${port}`;
      const res = await fetch(`${baseUrl}${route}`, requestOptions);
      const resOut = await res.text();
      setResponse(resOut);
    } catch (error) {
      setResponse(`Received an error: ${String(error)}`);
    }
  };

  const handleHover =
    (color: string) => (event: MouseEvent<HTMLButtonElement>) => {
      event.currentTarget.style.backgroundColor = color;
    };

  const handleRouteChange = (event: ChangeEvent<HTMLInputElement>) => {
    setRoute(event.target.value);
  };

  const handleMessageChange = (
    event: ChangeEvent<HTMLTextAreaElement>,
  ) => {
    setMessage(event.target.value);
  };

  const handlePortChange = (event: ChangeEvent<HTMLInputElement>) => {
    setPort(event.target.value);
  };

  const handleMethodChange = (event: ChangeEvent<HTMLSelectElement>) => {
    setMethod(event.target.value as HttpMethod);
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        backgroundColor: "#011013",
        fontFamily: "sans-serif",
        paddingTop: "7rem",
      }}
    >
      <main
        style={{
          maxWidth: "1250px",
          margin: "0 auto",
          padding: "0 1rem",
        }}
      >
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: "1.5rem",
          }}
        >
          {/* Request Form Section */}
          <div
            style={{
              backgroundColor: "#022d35",
              padding: "1.5rem",
              borderRadius: "0.5rem",
              boxShadow: "0 4px 6px rgba(0,0,0,0.1)",
            }}
          >
            <h2
              style={{
                color: "#E5E7EB",
                fontSize: "1.875rem",
                fontWeight: "600",
                marginBottom: "1rem",
              }}
            >
              HTTP Request
            </h2>

            <form onSubmit={handleSubmit}>
              {/* Port Input */}
              <div style={{ marginBottom: "1rem" }}>
                <label
                  style={{
                    display: "block",
                    marginBottom: "0.5rem",
                    color: "#E5E7EB",
                    fontWeight: "500",
                    fontSize: "0.875rem",
                  }}
                >
                  Port (Optional)
                </label>
                <input
                  type="number"
                  min="0"
                  max="65535"
                  value={port}
                  onChange={handlePortChange}
                  style={{
                    width: "100%",
                    padding: "0.5rem 0.75rem",
                    border: "1px solid #4b5563",
                    borderRadius: "0.375rem",
                    outline: "none",
                    fontSize: "1rem",
                    backgroundColor: "#1f2937",
                    color: "#E5E7EB",
                  }}
                />
              </div>

              {/* Route Input */}
              <div style={{ marginBottom: "1rem" }}>
                <label
                  htmlFor="route"
                  style={{
                    display: "block",
                    marginBottom: "0.5rem",
                    color: "#E5E7EB",
                    fontWeight: "500",
                    fontSize: "0.875rem",
                  }}
                >
                  Route
                </label>
                <input
                  type="text"
                  id="route"
                  placeholder="Enter the route (e.g., /api/acm/industry)"
                  value={route}
                  onChange={handleRouteChange}
                  style={{
                    width: "100%",
                    padding: "0.5rem 0.75rem",
                    border: "1px solid #4b5563",
                    borderRadius: "0.375rem",
                    outline: "none",
                    boxSizing: "border-box",
                    fontSize: "1rem",
                    backgroundColor: "#1f2937",
                    color: "#E5E7EB",
                  }}
                />
              </div>

              {/* Method Selector */}
              <div style={{ marginBottom: "1rem" }}>
                <label
                  style={{
                    display: "block",
                    marginBottom: "0.5rem",
                    color: "#E5E7EB",
                    fontWeight: "500",
                    fontSize: "0.875rem",
                  }}
                >
                  Method
                </label>
                <select
                  value={method}
                  onChange={handleMethodChange}
                  style={{
                    width: "100%",
                    padding: "0.5rem 0.75rem",
                    border: "1px solid #4b5563",
                    borderRadius: "0.375rem",
                    backgroundColor: "#ffffff",
                    fontSize: "1rem",
                    cursor: "pointer",
                    outline: "none",
                    color: "#000000",
                    fontWeight: "500",
                  }}
                >
                  {dropdownOptions.map((option) => (
                    <option key={option} value={option} style={{ color: "#000000" }}>
                      {option}
                    </option>
                  ))}
                </select>
              </div>

              {/* Body Textarea */}
              <div style={{ marginBottom: "1rem" }}>
                <label
                  htmlFor="message"
                  style={{
                    display: "block",
                    marginBottom: "0.5rem",
                    color: "#E5E7EB",
                    fontWeight: "500",
                    fontSize: "0.875rem",
                  }}
                >
                  Body
                </label>
                <textarea
                  id="message"
                  rows={5}
                  placeholder="What message hath thou come with?"
                  value={message}
                  onChange={handleMessageChange}
                  style={{
                    width: "100%",
                    padding: "0.5rem 0.75rem",
                    border: "1px solid #4b5563",
                    borderRadius: "0.375rem",
                    outline: "none",
                    boxSizing: "border-box",
                    fontSize: "1rem",
                    resize: "vertical",
                    backgroundColor: "#1f2937",
                    color: "#E5E7EB",
                  }}
                />
              </div>

              {/* Submit Button */}
              <button
                type="submit"
                style={{
                  width: "100%",
                  backgroundColor: "#1a1d24",
                  color: "white",
                  fontSize: "1.125rem",
                  fontWeight: "500",
                  padding: "0.5rem 1rem",
                  border: "none",
                  borderRadius: "0.375rem",
                  cursor: "pointer",
                  transition: "background-color 0.2s",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = "#000000";
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = "#1a1d24";
                }}
              >
                Send
              </button>
            </form>
          </div>

          {/* Response Section */}
          <div>
            <h2
              style={{
                color: "#E5E7EB",
                fontSize: "1.875rem",
                fontWeight: "600",
                marginBottom: "1rem",
              }}
            >
              Responses
            </h2>
            <div
              style={{
                backgroundColor: "#022d35",
                padding: "1.5rem",
                borderRadius: "0.5rem",
                boxShadow: "0 4px 6px rgba(0,0,0,0.1)",
                minHeight: "300px",
              }}
            >
              {response.length > 0 ? (
                <pre
                  style={{
                    color: "#E5E7EB",
                    fontSize: "1rem",
                    whiteSpace: "pre-wrap",
                    wordBreak: "break-word",
                    margin: 0,
                  }}
                >
                  {response}
                </pre>
              ) : (
                <div
                  style={{
                    textAlign: "center",
                    color: "#9CA3AF",
                    fontSize: "1rem",
                    paddingTop: "2rem",
                  }}
                >
                  No posts yet!
                </div>
              )}
            </div>
          </div>
        </div>
      </main>

      <footer
        style={{
          padding: "1.5rem 1rem",
          marginTop: "2rem",
          textAlign: "center",
          color: "#6b7280",
        }}
      >
        <p>&copy; 2025 Katskt</p>
      </footer>
    </div>
  );
}

