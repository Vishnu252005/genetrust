import * as functions from "firebase-functions";
import { VertexAI } from "@google-cloud/vertexai";
import { defineSecret } from "firebase-functions/v2/params";

const geminiApiKeySecret = defineSecret("GEMINI_API_KEY"); // The secure way

// Callable function that your Flutter app will call
export const callGemini = functions
  .runWith({ secrets: [geminiApiKeySecret] })
  .https.onCall(async (data, context) => {
    // 1. Check if the user is authenticated (optional but recommended)
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be logged in to use this feature."
      );
    }

    // 2. Get the prompt from the data sent by the Flutter app
    const prompt = data.prompt;
    if (!prompt || typeof prompt !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with one argument 'prompt' that is a string."
      );
    }

    try {
      // Initialize Vertex with your Cloud project and location
      const vertexAI = new VertexAI({
        project: process.env.GCLOUD_PROJECT!,
        location: "us-central1", // Or your preferred region
      });

      const model = "gemini-1.5-flash-latest"; // Or your preferred model

      // Instantiate the model
      const generativeModel = vertexAI.getGenerativeModel({ model });

      // Generate content
      const result = await generativeModel.generateContent(prompt);
      const response = result.response;
      const text = response.candidates?.[0].content.parts[0].text;

      if (!text) {
        throw new functions.https.HttpsError(
          "internal",
          "Failed to get a response from Gemini."
        );
      }

      // 4. Return the response text to the Flutter app
      return { responseText: text };
    } catch (error) {
      console.error("Error calling Gemini API:", error);
      throw new functions.https.HttpsError(
        "internal",
        "An unexpected error occurred."
      );
    }
  });