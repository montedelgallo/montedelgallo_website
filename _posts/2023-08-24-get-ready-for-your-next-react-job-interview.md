---
title: "Ace Your React Interview: Comprehensive Guide & Key Concepts"
meta_title: "30+ React Interview Questions and Answers | Monte del Gallo"
description: "A guide to over 30 questions that come up in React interviews, from the Virtual DOM and JSX to components and rendering, each with a short, clear answer."
lang: en
page_id: post-get-ready-for-your-next-react-job-interview
permalink: /blog/get-ready-for-your-next-react-job-interview/
date: 2023-08-24 11:33:51 +0000
author: Giovanni Panasiti
categories: [frontend]
excerpt: "A curated collection of over 30 questions that frequently surface in React interviews, with succinct answers that show React’s core principles and its advanced nuances."
cover: /assets/img/blog/react-interview-cover.webp
cover_alt: "A code editor showing React Router code, with the terminal tab open below"
cover_width: 1200
cover_height: 800
lang-exclusive: [en]
---
In today’s competitive tech landscape, a successful interview often hinges not just on your skills, but on your preparation. React, as one of the leading libraries in front-end development, frequently sits at the center of such interviews, and the questions can range from basic to deeply intricate. “Ace Your React Interview: Comprehensive Guide & Key Concepts” is tailored for those aspiring to shine in such pivotal moments.

Within this guide, you’ll find a curated collection of over 30 pivotal questions that frequently surface in React interviews. But, more than just questions, we provide you with succinct, articulate answers that showcase a profound understanding of React’s core principles and advanced nuances. Think of this not just as a study guide, but as a blueprint to articulate your React expertise confidently and convincingly. Whether you’re an experienced developer aiming to refresh your knowledge, or you’re stepping into the React realm for the first time, this guide is your ally. Let’s ensure that when the spotlight is on, you’re not only ready but poised to impress.

## Questions

- Explain what is the Virtual DOM in React
- What are the differences between the Virtual DOM and the DOM?
- What is JSX?
- What do you understand when we talk about Render in React?
- Explain the concept of Components in React
- What are props in React and what are the main differences with state?
- Props:
- State:
- How can you update the state of a component?
- Class Components:
- Functional Components:
- What are synthethic events in React?
- What are refs in React, give an example of when would you use one.
- How does React render process work?
- What are keys in React and why are they important?
- How can you reuse logic in functional components?
- What is the difference between a controlled and uncontrolled component in React?
- Explain the main difference between server side rendering and client side rendering in React
- How would you avoid unnecessary renders in a React component?
- What is a Portal in React?
- State the main difference between useEffect and useLayoutEffect
- Where do you usually fetch data in React?
- What are hooks in React?
- If you wanted a component to perform an action only once when the component initially rendered how would you achieve it
- with a function component?
- What is prop-drilling, and how can you avoid it?
- How can you reset a component’s state to its initial state?
- Explain the difference between useState and useEffect.
- If you have to set a key value in a component, from where would you get that value?
- Explain the concept of lazy loading React components
- Explain the main differences between useMemo and useCallback
- Why would you ever use forwardRef in React?
- At what point does the useEffect cleanup function run?
- Explain the concept of Reducers and Context in React
- How would you catch render errors in React components at the global scope?
- How does useEffect check changes in its array dependency?

### Explain what is the Virtual DOM in React

The **Virtual DOM** in React is a **lightweight representation** of the actual DOM elements. The rendering engine can quickly make changes to the Virtual DOM and then subsequently update the real DOM in a more efficient and optimized way. The primary benefit is that it **minimizes direct manipulations** of the actual DOM, resulting in **faster and smoother updates** to the user interface.

### What are the differences between the Virtual DOM and the DOM?

The **Virtual DOM** and the **DOM** are both critical concepts in web development, especially when working with React. Here are their primary differences:

- **Representation:** The **DOM** (Document Object Model) is a programming interface and structured representation of a webpage, allowing developers to interact with and manipulate the page content, structure, and styles. On the other hand, the **Virtual DOM** is a **lightweight** copy of the actual DOM in React, which helps in determining the most efficient way to update the real DOM.
- **Efficiency:** Directly manipulating the DOM can be slow and inefficient, especially with frequent changes. The **Virtual DOM** enables React to determine the minimal number of DOM changes required by comparing the current Virtual DOM with the next version (a process called **diffing**) and then applying only the necessary updates.
- **Existence:** While the **DOM** is a standard that exists in all web browsers, the **Virtual DOM** is specific to React and certain other modern web libraries or frameworks.

Here’s a basic code illustration to emphasize the concept:

```
// Traditional DOM manipulation:
const element = document.createElement('div');
element.textContent = 'Hello, DOM!';
document.body.appendChild(element);

// React's way using Virtual DOM:
import React from 'react';
function App() {
    return <div>Hello, Virtual DOM!</div>;
}
```

### What is JSX?

**JSX**, or JavaScript XML, is a syntax extension for JavaScript, predominantly used with React. It allows developers to write HTML-like code within their JavaScript code, leading to a more intuitive and readable way to describe the UI components.

- **Combination:** JSX essentially allows you to combine JavaScript and HTML. This synergy makes it easier to visualize the UI structure directly within the component logic.
- **Transpilation:** Browsers don’t natively understand JSX. Therefore, tools like **Babel** are used to transpile JSX into regular JavaScript code that browsers can interpret.
- **Components:** With JSX, React components can be defined using a syntax that’s visually similar to HTML, making it straightforward to define and understand the component’s structure.

Here’s a simple illustration of JSX in action:

```
// Without JSX:
React.createElement('div', { className: 'greeting' }, 'Hello, world!');

// With JSX:
<div className="greeting">Hello, world!</div>
```

Notice how the JSX version is more concise and resembles traditional HTML, offering better readability.

### What do you understand when we talk about Render in React?

In React, when we talk about **render**, we are referring to the process of translating the application’s state and props into a visual representation within the browser. Rendering determines how the UI should look based on the data available to the component.

- **Initial Render:** The first time a React component is added to the DOM, it undergoes an initial render, creating the visual output for the user.
- **Re-rendering:** When there are changes in the component’s state or props, React determines if an update to the UI is required. If needed, a re-render is triggered to reflect the changes.
- **Virtual DOM:** Instead of making direct changes to the real DOM, React first updates the Virtual DOM. It then compares (or “diffs”) the current Virtual DOM with the new one and calculates the most efficient way to make changes to the real DOM.

Here’s a basic example illustrating the rendering process in a React component:

```
import React, { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div>
      <p>You clicked {count} times</p>
      <button onClick={() => setCount(count + 1)}>
        Click me
      </button>
    </div>
  );
}
```

Every time the button in the `Counter` component is clicked, the state (`count`) changes, which triggers a re-render to update the displayed click count.

### Explain the concept of Components in React

In React, **Components** are the building blocks of the user interface. They allow you to split the UI into independent, reusable pieces, and think about each piece in isolation. Components can be likened to custom HTML elements with their own structure, logic, and behavior.

- **Reusable:** Components can be reused across different parts of an application. This promotes a DRY (Don’t Repeat Yourself) principle.
- **Stateful and Stateless:** Components can either maintain their own data state (stateful) or receive data entirely through props (stateless).
- **Class and Functional:** Historically, components were primarily class-based, but with the introduction of React hooks, functional components can now manage state and side effects as well.
- **Composition:** Components can be nested within other components, enabling the creation of more complex UIs through composition.

Here’s a basic example of a React component:

```
// Functional Component
function Greeting(props) {
  return <h1>Hello, {props.name}!</h1>;
}
```

And using the component:

```
<Greeting name="John" />
```

This would render the text “Hello, John!” on the screen. The component encapsulates the logic and structure needed to create this piece of the UI, making it easy to reuse wherever a greeting is needed.

### What are props in React and what are the main differences with state?

In React, **props** (short for “properties”) and **state** are two key concepts that help manage data in a component. While they both hold information that influences the output of a render, they serve different purposes and have distinct characteristics.

### Props:

- **Immutable:** Props are **read-only**. This means a component should never modify its own props.
- **Passed from Parent:** Props are passed to a component from its parent component. They allow components to communicate with each other.
- **External Data:** Think of props as arguments or parameters you pass to a function.

### State:

- **Mutable:** State is **changeable** data. When state changes in a component, the component re-renders.
- **Internal Data:** State represents data that a component’s event handlers may change to trigger a user interface update.
- **Lifecycle:** State can have a lifecycle, with mounting, updating, and unmounting phases.

Highlighting the differences:

```
// Using props
function Welcome(props) {
  return <h1>Hello, {props.name}</h1>;
}

// Using state
class Counter extends React.Component {
  constructor(props) {
    super(props);
    this.state = { count: 0 };
  }

  increment = () => {
    this.setState({ count: this.state.count + 1 });
  }

  render() {
    return (
      <div>
        <p>Count: {this.state.count}</p>
        <button onClick={this.increment}>Increment</button>
      </div>
    );
  }
}
```

In the first example, the `Welcome` component receives the name to display via props. In the second example, the `Counter` component maintains its own count in the state, which can be changed using the increment function.

### How can you update the state of a component?

Updating the **state** of a component in React is crucial for ensuring that the user interface remains in sync with the underlying data. In React, you should never directly modify the state. Instead, you use the **setState** method (in class components) or the **useState** hook (in functional components) to update the state.

### Class Components:

In class components, the **setState** method is used:

```
class Counter extends React.Component {
  constructor(props) {
    super(props);
    this.state = { count: 0 };
  }

  handleIncrement = () => {
    this.setState({ count: this.state.count + 1 });
  }

  render() {
    return (
      <div>
        <p>Count: {this.state.count}</p>
        <button onClick={this.handleIncrement}>Increment</button>
      </div>
    );
  }
}
```

### Functional Components:

In functional components, the **useState** hook is commonly used to manage state:

```
import React, { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);

  const handleIncrement = () => {
    setCount(count + 1);
  }

  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={handleIncrement}>Increment</button>
    </div>
  );
}
```

In both examples, the state update functions (**setState** and **setCount**) trigger a re-render of the component, ensuring the displayed count reflects the updated state.

### What are synthethic events in React?

In React, **Synthetic Events** are wrappers around the browser’s native events. They aim to provide a consistent event system across different browsers, ironing out any inconsistencies and ensuring a unified behavior in your application.

- **Cross-Browser Compatibility:** Synthetic Events encapsulate the behavior of native browser events, offering the same interface regardless of underlying browser differences.
- **Performance:** React reuses synthetic event objects for better performance. This reduces the overhead of creating a new event object for every event.
- **Pooling:** After the event callback has been invoked, React “pools” the synthetic events, nullifying their properties. This ensures a reduced memory footprint.
- **Consistent Properties:** Properties and methods on the synthetic event are consistent across different browsers.

Here’s an example showcasing the use of a synthetic event:

```
import React from 'react';

function ClickableComponent() {
  const handleClick = (event) => {
    event.preventDefault(); // Using a synthetic event method
    console.log(event.type); // Outputs: "click"
  }

  return (
    <a href="https://www.example.com" onClick={handleClick}>
      Click Me
    </a>
  );
}
```

In the example above, the `handleClick` function receives a synthetic event object when the link is clicked. This ensures that the event behavior is consistent, no matter which browser the code runs in.

### What are refs in React, give an example of when would you use one.

In React, **refs** (short for “references”) provide a way to directly access the DOM elements or React elements created in the render method. This is useful in cases where you need to bypass the typical data flow mechanisms of React, such as when you need to focus an input element, trigger imperative animations, or integrate with third-party libraries.

- **Direct Access:** Refs allow direct access to DOM elements, which is generally discouraged in favor of a declarative approach, but can be essential in some situations.
- **Avoid Overuse:** It’s important to avoid overusing refs. React’s declarative approach usually negates the need for them. Use them as a last resort or in scenarios where their necessity is clear.
- **createRef and useRef:** Refs can be created using `React.createRef()` in class components and `useRef()` hook in functional components.

Here’s an example showcasing the use of refs to focus on an input element:

```
import React, { useRef, useEffect } from 'react';

function FocusInput() {
  // Create a ref object
  const inputRef = useRef(null);

  useEffect(() => {
    // Focus the input element when the component mounts
    inputRef.current.focus();
  }, []);

  return (
    <input ref={inputRef} type="text" placeholder="I will be focused on mount" />
  );
}
```

In this example, as soon as the `FocusInput` component mounts, the input element is automatically focused using the ref. This illustrates a common use-case for refs: controlling focus programmatically.

### How does React render process work?

The **React render process** is a sequence of steps the library follows to convert React components into a visual representation in the browser. It’s optimized for performance and ensures efficient updates to the UI. Here’s a simplified breakdown:

1. **JSX Compilation:** During the development phase, JSX (an XML-like syntax extension for JavaScript) is compiled into regular JavaScript using tools like Babel. It gets transformed into `React.createElement()` calls.
2. **Initial Render:** When a React application starts, it goes through the initial rendering phase. All components return their defined output (typically other components, HTML elements, etc.).
3. **Virtual DOM Creation:** React creates a lightweight representation of the output, known as the Virtual DOM. This allows React to determine changes in an optimized manner.
4. **Reconciliation:** When there’s a change in state or props, React triggers a re-render. Instead of updating the real DOM directly, React first updates the Virtual DOM.
5. **Diffing:** React compares (or “diffs”) the previous Virtual DOM with the new one to determine the most efficient series of changes.
6. **Committing Updates:** After calculating the necessary changes, React updates the real DOM. This is the phase where users see updates on their screen.
7. **Batching:** To further enhance performance, React batches multiple `setState()` calls together into a single update, reducing the number of DOM manipulations.
8. **Component Lifecycle:** Throughout the render process, React components go through a series of lifecycle methods (in class components) or effects (in functional components with hooks) allowing developers to plug in code at specific points.

By following this process, React ensures the UI remains responsive and updates efficiently, avoiding unnecessary computations or DOM updates.

### What are keys in React and why are they important?

In React, **keys** are special attributes you should provide when creating lists of elements. They help React identify which items have been added, changed, or removed, and they play a crucial role in optimizing the performance of updates, especially in lists or dynamic content.

- **Identity:** Keys give elements a stable identity. They should be unique among siblings but don’t need to be globally unique.
- **Reconciliation Process:** During React’s reconciliation (diffing) process, keys help to correctly match elements in the original tree structure with those in the subsequent tree.
- **Performance:** Without keys, React might need to re-render more components than necessary, leading to decreased performance.
- **Stateful Components:** Using keys ensures that the state associated with an item is maintained even when the order changes or items are added/removed.

Here’s a basic example illustrating the use of keys:

```
import React from 'react';

function ItemList(props) {
  const items = props.items;

  return (
    <ul>
      {items.map(item =>
        <li key={item.id}>{item.name}</li>
      )}
    </ul>
  );
}
```

In this example, each item has a unique `id` that is used as the key. This ensures that React can efficiently determine changes in the list and update the DOM accordingly.

**Note:** It’s generally discouraged to use indexes as keys if the list can change over time. This can lead to bugs and negatively impact performance.

### How can you reuse logic in functional components?

In React, when working with functional components, the primary way to reuse logic is through the use of **custom hooks**. Custom hooks allow you to extract component logic into reusable functions.

- **Custom Hooks:** They are JavaScript functions that can use other hooks. By convention, they start with the word `use`, and they allow you to share and reuse stateful logic across different components.
- **Isolation:** Custom hooks allow for better isolation and testing of logic, making your components cleaner and easier to maintain.
- **Composition:** Multiple custom hooks can be combined to create more complex functionality, making them composable.

Here’s a simple example illustrating the use of custom hooks:

```
import { useState } from 'react';

// Custom hook to handle input changes
function useInput(initialValue) {
  const [value, setValue] = useState(initialValue);
  const handleChange = (e) => {
    setValue(e.target.value);
  };

  return [value, handleChange];
}

function MyComponent() {
  const [username, handleUsernameChange] = useInput('');
  const [email, handleEmailChange] = useInput('');

  return (
    <div>
      <input value={username} onChange={handleUsernameChange} placeholder="Username" />
      <input value={email} onChange={handleEmailChange} placeholder="Email" />
    </div>
  );
}
```

In the example above, the `useInput` custom hook manages the state and change logic of an input field. By using this custom hook, we can avoid repeating the same logic for different input fields, showcasing the power of reusable logic in functional components.

### What is the difference between a controlled and uncontrolled component in React?

In React, components that handle form elements can be classified into two categories: **controlled** and **uncontrolled** components.

- **Controlled Components:**
  - In a controlled component, the form data is managed by the React state. The value of the input is always driven by the React state.
  - Whenever there’s a change in the input, a handler function (like `onChange`) is invoked to update the state, which in turn updates the input’s value.
  - It offers more predictability and can be directly influenced by the component’s state.
- **Uncontrolled Components:**
  - In an uncontrolled component, the form data is managed by the DOM itself, not by the React state.
  - To get the value from an input in an uncontrolled component, you’d use a ref to directly access the DOM element.
  - They are similar to traditional HTML form inputs and might be simpler for integrating React with non-React code.

Here’s a comparison with examples:

```
// Controlled Component
function ControlledInput() {
  const [value, setValue] = useState('');

  return (
    <input value={value} onChange={e => setValue(e.target.value)} />
  );
}

// Uncontrolled Component
function UncontrolledInput() {
  const inputRef = useRef(null);

  const showAlert = () => {
    alert(inputRef.current.value);
  }

  return (
    <div>
      <input ref={inputRef} />
      <button onClick={showAlert}>Show Value</button>
    </div>
  );
}
```

Generally, controlled components are recommended in React as they allow for more predictable behavior and better integration with React’s declarative nature.

### Explain the main difference between server side rendering and client side rendering in React

In the context of React applications, rendering can occur either on the server or the client side. The choice between **Server Side Rendering (SSR)** and **Client Side Rendering (CSR)** can significantly impact performance, SEO, and user experience. Here are the primary differences:

- **Server Side Rendering (SSR):**
  - The React components are rendered on the server into a static HTML string.
  - Users see the content faster as the server sends the rendered page directly. This can result in a faster **First Contentful Paint (FCP)**.
  - It can be beneficial for SEO, as search engine crawlers receive a fully rendered page.
  - Popular frameworks like **Next.js** simplify the SSR process for React applications.
  - Requires a server to process requests, which can lead to increased server load.
- **Client Side Rendering (CSR):**
  - The React components are rendered directly in the browser. Initially, the server sends a blank or loading page, and the actual content is populated as the JavaScript executes.
  - It might result in a slower initial page load, as the browser has to load, parse, and execute the JavaScript before displaying content.
  - Once loaded, navigating between pages or views can be faster due to the assets and React being already in memory.
  - SEO might be more challenging (though search engines have gotten better at indexing JavaScript applications).
  - Frameworks like **Create React App** set up CSR-based React applications.

In practice, many applications leverage a combination of both, known as **Hybrid Rendering**, to optimize performance, SEO, and user experience. They may use SSR for the initial load and CSR for subsequent dynamic updates.

### How would you avoid unnecessary renders in a React component?

Ensuring efficient rendering is key to maximizing the performance of React applications. Unnecessary renders can slow down the app and lead to a poor user experience. Here are ways to avoid them:

- **Use PureComponent:**
  - If you’re using class components, extend `PureComponent` instead of `Component`. This ensures a shallow comparison of state and props, preventing unnecessary renders when data hasn’t changed.
- **Utilize React.memo:**
  - For functional components, wrap your component with `React.memo`. It’s similar to `PureComponent` and does a shallow comparison of props.
- **Optimize state and props:**
  - Ensure that you’re only updating state or props when necessary. Avoid creating new references (objects or arrays) unless there’s a change in the data.
- **Use Callbacks Wisely:**
  - Use the `useCallback` hook to memoize callback functions, preventing them from being recreated every render.

    ```
    const increment = useCallback(() => {
      setCount(prevCount => prevCount + 1);
    }, []);
    ```
- **Memoize Computations:**
  - If you have computations derived from state or props, use the `useMemo` hook to ensure they’re recalculated only when necessary.

    ```
    const doubledValue = useMemo(() => {
      return value * 2;
    }, [value]);
    ```
- **Use Context Sparingly:**
  - Remember that any value change in a `React.Context` will re-render all components consuming that context. Break contexts into smaller parts if possible or use libraries like `react-query` for more granular control.
- **Profile with DevTools:**
  - Use the React DevTools’ profiler to inspect which components are re-rendering and why. This helps in identifying bottlenecks and optimizing renders.

By being mindful of renders and employing optimization techniques, you can ensure a smooth and responsive user experience.

### What is a Portal in React?

In React, a **Portal** provides a way to render children outside the parent DOM hierarchy, yet it retains the same context and event bubbling behavior as if they were inside the parent. This is particularly useful for UI elements like modals, popups, and tooltips which might be visually positioned outside the component but need to stay within the React component logic.

- **Advantages:**
  - It can help with CSS styling issues, especially with z-index or overflow problems.
  - It ensures that the component’s behavior remains consistent, even if visually rendered outside the main UI tree.
- **Usage:**
  - React provides a `ReactDOM.createPortal()` method for this purpose.

    ```
    import ReactDOM from 'react-dom';

    function Modal(props) {
      return ReactDOM.createPortal(
        <div className="modal">
          {props.children}
        </div>,
        document.getElementById('modal-root')
      );
    }
    ```
  - In the example above, the `Modal` component renders its children into a `modal-root` DOM node outside the main app hierarchy.

Using Portals efficiently can greatly simplify the implementation and improve the behavior of overlays and floating UI elements in a React application.

### State the main difference between useEffect and useLayoutEffect

**useEffect** and **useLayoutEffect** are both hooks in React that allow you to perform side effects in function components. However, they differ primarily in the timing of their execution in relation to rendering:

- **useEffect:**
  - It runs asynchronously and after the browser has painted the updated screen.
  - Typically used for most side effects, such as data fetching, setting up subscriptions, etc.
  - Doesn’t block the browser from updating the screen.
- **useLayoutEffect:**
  - It runs synchronously after all DOM mutations but before the screen is updated or painted.
  - Useful when you need to make DOM measurements or updates and want to ensure they occur before the screen is repainted, preventing flickers.
  - Should be used sparingly as it can block the render process.

In most scenarios, `useEffect` is sufficient and should be preferred due to its non-blocking nature. `useLayoutEffect` is used for more specific cases where the effect must be synchronized with the layout phase.

### Where do you usually fetch data in React?

In React, data fetching commonly occurs in the **component lifecycle methods** (for class components) or within the **effect hooks** (for functional components). Here’s how it’s typically done in each approach:

- **Class Components:**
  - The `componentDidMount` lifecycle method is a popular place to fetch data as it ensures that the component is fully mounted in the DOM before making the request.

    ```
    class DataComponent extends React.Component {
      componentDidMount() {
        fetch('/api/data')
          .then(response => response.json())
          .then(data => this.setState({ data }));
      }
      // ... rest of the component
    }
    ```
- **Functional Components:**
  - The `useEffect` hook is used for side effects, including data fetching, in functional components. To fetch data when the component mounts, you’d use `useEffect` with an empty dependency array.

    ```
    function DataComponent() {
      const [data, setData] = useState(null);

      useEffect(() => {
        fetch('/api/data')
          .then(response => response.json())
          .then(fetchedData => setData(fetchedData));
      }, []);  // Empty dependency array means this effect runs once after component mounts

      // ... rest of the component
    }
    ```

Regardless of the approach, it’s essential to handle loading states, errors, and potential side effects efficiently for a seamless user experience. Libraries like **react-query** and **SWR** can abstract and optimize many of these concerns, simplifying data-fetching patterns in React applications.

### What are hooks in React?

In React, **Hooks** are functions that allow you to “hook into” React state and lifecycle features directly from function components. They were introduced in React 16.8 and enable developers to use state and other React features without having to write class components.

- **Benefits:**
  - Facilitates the creation of cleaner and more readable code.
  - Enables better logic encapsulation and reusability.
  - Reduces the complexity of components by avoiding the “this” keyword and lifecycle methods.
- **Common Hooks:**
  - `useState`: Allows you to add state to functional components.

    ```
    const [count, setCount] = useState(0);
    ```
  - `useEffect`: Performs side effects (like data fetching, manual DOM manipulation, etc.) in functional components.

    ```
    useEffect(() => {
      document.title = `Count: ${count}`;
    }, [count]);
    ```
  - `useContext`: Accesses the value from a React context without using a Context Consumer.

    ```
    const theme = useContext(ThemeContext);
    ```
- **Additional Hooks:** React also offers hooks like `useReducer`, `useCallback`, `useMemo`, `useRef`, and `useLayoutEffect`, among others.
- **Custom Hooks:** You can also create your own hooks, allowing you to extract component logic into reusable functions. Custom hooks are a way to reuse stateful logic, not state itself.

Overall, hooks provide a more intuitive way to use React’s features within function components, promoting cleaner and more maintainable code.

### If you wanted a component to perform an action only once when the component initially rendered how would you achieve it with a function component?

To ensure a function component performs an action only once upon its initial render, you would utilize the **useEffect** hook with an empty dependency array. This ensures that the effect runs only once, similar to the `componentDidMount` lifecycle method in class components.

```
import React, { useEffect } from 'react';

function MyComponent() {
  useEffect(() => {
    // Action to be performed only on the initial render
    console.log('Component did mount!');

  }, []);  // Empty dependency array ensures this runs once after component mounts

  return (
    <div>
      My Component Content
    </div>
  );
}
```

By using an empty dependency array in `useEffect`, the effect does not re-run after the initial execution since no state or prop values are being watched for changes. This is a common pattern for actions that should only occur once, such as initial data fetching or setting up event listeners.

### What is prop-drilling, and how can you avoid it?

**Prop-drilling**, also known as “prop-threading”, refers to the process of passing data through multiple layers of components (from parent to descendant) via props, even if some intermediary components don’t need the data themselves. This can lead to code that is hard to maintain and trace, especially in deep component hierarchies.

```
function ParentComponent(props) {
  return <ChildComponent someProp={props.someProp} />;
}

function ChildComponent(props) {
  return <GrandchildComponent someProp={props.someProp} />;
}

function GrandchildComponent(props) {
  return <div>{props.someProp}</div>;
}
```

Here, even though only `GrandchildComponent` needs `someProp`, it’s being passed through each layer of the hierarchy.

**Ways to avoid prop-drilling:**

- **Context API:** Use React’s built-in Context API to provide data to components further down the tree.

  ```
  const SomeContext = React.createContext();

  function ParentComponent(props) {
    return (
      <SomeContext.Provider value={props.someProp}>
        <ChildComponent />
      </SomeContext.Provider>
    );
  }

  function GrandchildComponent() {
    const someProp = React.useContext(SomeContext);
    return <div>{someProp}</div>;
  }
  ```
- **Component Composition:** Break down complex components and use component composition to avoid passing unnecessary props.
- **Redux or other state management libraries:** For larger applications, use state management solutions to manage and distribute your application’s state without prop-drilling.

By using these strategies, you can maintain cleaner, more readable, and more efficient React codebases that are less prone to bugs and easier to refactor.

### How can you reset a component’s state to its initial state?

To reset a component’s state to its initial state in React, there are several methods you can employ:

- **Using a Reference:** Store the initial state in a reference and reset the state using that reference.

  ```
  import React, { useState, useRef } from 'react';

  function MyComponent() {
    const initialState = { count: 0 };
    const [state, setState] = useState(initialState);
    const stateRef = useRef(initialState);

    const resetState = () => {
      setState(stateRef.current);
    };

    return (
      <div>
        Count: {state.count}
        <button onClick={() => setState({ count: state.count + 1 })}>Increment</button>
        <button onClick={resetState}>Reset</button>
      </div>
    );
  }
  ```
- **Using a Function with useState:** useState can accept a function to provide an initial state. If you encapsulate the initial state logic in a function, you can call it both for setting the initial state and resetting it.

  ```
  function MyComponent() {
    const createInitialState = () => ({ count: 0 });
    const [state, setState] = useState(createInitialState);

    const resetState = () => {
      setState(createInitialState());
    };

    return (
      <div>
        Count: {state.count}
        <button onClick={() => setState({ count: state.count + 1 })}>Increment</button>
        <button onClick={resetState}>Reset</button>
      </div>
    );
  }
  ```

Both approaches are valid and can be used based on the specific use case and developer preference. The key is to maintain the initial state’s representation and use it when you want to revert back to it.

### Explain the difference between useState and useEffect.

**useState** and **useEffect** are both hooks introduced in React 16.8, but they serve very different purposes:

- **useState:**

  This hook allows you to add state to functional components. Before hooks, state could only be used in class components.

  ```
  import React, { useState } from 'react';

  function Counter() {
    const [count, setCount] = useState(0); // initial value is 0

    return (
      <div>
        {count}
        <button onClick={() => setCount(count + 1)}>Increment</button>
      </div>
    );
  }
  ```
- **useEffect:**

  This hook is used to perform side effects (like data fetching, DOM manipulation, setting up event listeners, etc.) in functional components. It can mimic the behavior of various lifecycle methods in class components, such as `componentDidMount`, `componentDidUpdate`, and `componentWillUnmount`.

  ```
  import React, { useState, useEffect } from 'react';

  function DataFetcher() {
    const [data, setData] = useState(null);

    useEffect(() => {
      fetch('/api/data')
        .then(response => response.json())
        .then(result => setData(result));
      // This runs after the component mounts and after every update
    }, []); // The empty array means it will only run once, similar to componentDidMount

    return (
      <div>
        {data}
      </div>
    );
  }
  ```

In essence:

- **useState** is for managing local state in functional components.
- **useEffect** is for handling side effects in functional components.

While both hooks provide essential functionality for modern React development, they cater to different aspects of component logic and behavior.

### If you have to set a key value in a component, from where would you get that value?

In React, a **key** is a special attribute you should provide to elements created dynamically from an array or iterable. It helps React identify which items have changed, been added, or been removed, thus ensuring efficient updates and re-renders. When determining a value for the key:

- **Unique Identifiers:**

  Often, the best approach is to use a unique identifier from your data. If the items come from a database, they might have a unique ID.

  ```
  const items = [
    { id: 1, name: 'Item 1' },
    { id: 2, name: 'Item 2' },
    // ...
  ];

  return items.map(item => <div key={item.id}>{item.name}</div>);
  ```
- **Array Index:**

  If there’s no unique identifier, you might consider using the array index. However, this isn’t recommended unless you’re certain the list doesn’t undergo reorder operations (like sort or splice), as it can lead to performance issues and bugs.

  ```
  const items = ['Item 1', 'Item 2'];

  return items.map((item, index) => <div key={index}>{item}</div>);
  ```
- **Generate Unique IDs:**

  If you don’t have a natural unique identifier, you can use libraries like **shortid** or **uuid** to generate them.

Remember, it’s crucial that the key is stable across re-renders for optimal performance. It should not be generated randomly for each render, as this would defeat its purpose.

### Explain the concept of lazy loading React components

**Lazy loading** is a technique in React where components are loaded and rendered only when they’re needed (typically when they come into the viewport or upon a particular event) instead of loading them upfront during the initial page load. This strategy can improve the performance and reduce the initial bundle size of your application, leading to faster load times.

React provides a built-in mechanism for lazy loading components using `React.lazy()` and `Suspense`.

- **React.lazy():**

  It allows you to render a dynamic import as a regular component. It automatically takes care of loading the component when it’s needed.

  ```
  const LazyLoadedComponent = React.lazy(() => import('./LazyLoadedComponent'));
  ```
- **Suspense:**

  Works in conjunction with `React.lazy()` and provides a fallback UI (like a loading spinner) while the component is being loaded.

  ```
  import React, { Suspense } from 'react';

  function App() {
    return (
      <div>
        <Suspense fallback=<div>Loading...</div>>
          <LazyLoadedComponent />
        </Suspense>
      </div>
    );
  }
  ```

For scenarios where you’d like to lazy-load components based on the viewport or other conditions, third-party libraries such as **react-loadable** or utilities like **IntersectionObserver** can be leveraged.

In summary, lazy loading React components is a powerful tool for optimizing the performance of your application, ensuring users download only what they need when they need it.

### Explain the main differences between useMemo and useCallback

**useMemo** and **useCallback** are both React hooks introduced to optimize performance by avoiding unnecessary recalculations and re-renders. While they have similar goals, they’re used in different scenarios:

- **useMemo:**

  It returns a **memoized value**. This hook is useful when you have computationally expensive calculations that you don’t want to execute on every render. Instead, you want them to recalculate only when specific dependencies change.

  ```
  import React, { useMemo } from 'react';

  function Component(props) {
    const computedValue = useMemo(() => {
      // some expensive calculation based on props.data
      return expensiveCalculation(props.data);
    }, [props.data]);

    return <div>{computedValue}</div>;
  }
  ```
- **useCallback:**

  It returns a **memoized callback function**. This hook is particularly useful when passing callbacks to performance-sensitive child components (like those wrapped in `React.memo`). By ensuring that the callback function reference remains consistent across renders (unless dependencies change), we prevent unnecessary re-renders of those child components.

  ```
  import React, { useCallback } from 'react';

  function ParentComponent() {
    const handleChildClick = useCallback(() => {
      // handle click logic
    }, []); // Empty dependency array means the callback will not change across re-renders

    return <ChildComponent onClick={handleChildClick} />;
  }
  ```

In essence:

- **useMemo** is about memoizing values.
- **useCallback** is about memoizing functions.

Both hooks accept a dependency array, and the provided value or function is recalculated/recreated only when values in this array change between renders.

### Why would you ever use forwardRef in React?

**forwardRef** in React is a tool for forwarding **refs** (references) to a child component. It is particularly useful in situations where you need to access the DOM elements or instance methods of a child component from a parent component. Here are some primary use cases:

- **Focus Management:**

  Often in user interfaces, after certain actions are completed, you might need to set focus on a particular child element for accessibility and usability purposes.
- **Animating Components:**

  When using libraries like **gsap** or **anime.js**, you might need direct access to the DOM node to perform animations.
- **Integration with Third-party Libraries:**

  Some external libraries require direct access to DOM nodes, and forwarding refs can be essential in these scenarios.
- **Reusable Components:**

  If you’re building a component library, you might use **forwardRef** to ensure components are extensible and can pass along refs when needed.

```
import React, { forwardRef } from 'react';

const CustomInput = forwardRef((props, ref) => {
  return <input ref={ref} {...props} />;
});

function App() {
  const inputRef = React.useRef(null);

  const handleButtonClick = () => {
    // Focus the input when the button is clicked
    inputRef.current.focus();
  };

  return (
    <div>
      <CustomInput ref={inputRef} />
      <button onClick={handleButtonClick}>Focus Input</button>
    </div>
  );
}
```

As shown above, **forwardRef** allows the parent component (`App` in this case) to access the underlying `input` DOM node of the `CustomInput` child component.

### At what point does the useEffect cleanup function run?

The **useEffect** hook in React provides a way to execute side effects (like setting up event listeners, fetching data, or subscribing to external sources) in functional components. Additionally, **useEffect** allows for a **cleanup function** which is used to undo these side effects and prevent potential memory leaks or unwanted behaviors.

The cleanup function of **useEffect** runs:

- Before the component is unmounted from the DOM, ensuring any setup done in the effect is properly cleaned up.
- Before re-running the effect when one of its dependencies has changed. This ensures that any previous effect is cleaned up before the new effect is run.

```
import React, { useState, useEffect } from 'react';

function ExampleComponent() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    // Side effect: Setting up an event listener
    const handleDocumentClick = () => {
      console.log('Document was clicked!');
    };
    document.addEventListener('click', handleDocumentClick);

    // Cleanup function
    return () => {
      // Cleaning up the event listener
      document.removeEventListener('click', handleDocumentClick);
    };
  }, [count]); // This effect depends on the 'count' state
}
```

In the example above:

- When `count` changes, before the new effect is executed, the cleanup function will run, removing the previous event listener.
- If the `ExampleComponent` is unmounted from the DOM, the cleanup function will also run, ensuring that the event listener is removed and preventing potential memory leaks.

In essence, the cleanup function is React’s way of ensuring that side effects don’t leave behind unwanted behaviors or resources.

### Explain the concept of Reducers and Context in React

Both **Reducers** and **Context** are powerful concepts in React, often used in tandem to manage global state and pass data throughout components without prop-drilling. Let’s dive into each concept separately:

#### Reducers

A **reducer** is a pure function that takes the current state and an action, then returns the next state. It follows the concept of the reducer in functional programming, where it “reduces” a collection to a single value. In the context of React (and state management libraries like Redux), reducers are used to handle state transitions in a predictable manner.

```
function counterReducer(state, action) {
  switch (action.type) {
    case 'INCREMENT':
      return { count: state.count + 1 };
    case 'DECREMENT':
      return { count: state.count - 1 };
    default:
      return state;
  }
}
```

In this example, the `counterReducer` adjusts the `count` based on the provided action type.

#### Context

The **Context** API provides a way to pass data through the component tree without having to pass props down manually at every level. It is designed to share data that can be considered “global”, such as themes, user authentication, or other shared utilities.

```
import React, { createContext, useContext } from 'react';

// Create a Context
const ThemeContext = createContext();

function App() {
  return (
    <ThemeContext.Provider value="dark">
      <ChildComponent />
    </ThemeContext.Provider>
  );
}

function ChildComponent() {
  // Use the Context value
  const theme = useContext(ThemeContext);
  return <div>Current theme is: {theme}</div>
}
```

In the example, the `ChildComponent` can access the theme value without receiving it as a direct prop, thanks to the Context API.

**Together:** These two concepts can be combined using the `useReducer` hook and the Context API to create a global state management solution. The reducer handles state logic and transitions, while the Context API distributes the state and functions to manipulate it throughout the component tree.

### How would you catch render errors in React components at the global scope?

To catch render errors in React components at the global scope, you would use a feature called **Error Boundaries**. An error boundary is a React component that catches JavaScript errors anywhere in their child component tree, logs those errors, and displays a fallback UI instead of the component tree that crashed.

#### Creating an Error Boundary

You can define an error boundary by creating a new component with the static method **getDerivedStateFromError()** and/or the instance method **componentDidCatch()**.

```
import React, { Component } from 'react';

class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error) {
    // Update state so the next render will show the fallback UI
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    // You can log the error to an error reporting service here
    console.error(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      // You can render any custom fallback UI here
      return <h1>Something went wrong.</h1>;
    }
    return this.props.children;
  }
}
```

#### Using the Error Boundary

Once you have an error boundary defined, you can wrap your entire application (or parts of it) inside this boundary.

```
function App() {
  return (
    <ErrorBoundary>
      <MainComponent />
    </ErrorBoundary>
  );
}
```

If any error occurs inside `MainComponent` or any of its children, the error boundary will catch it and display the fallback UI, ensuring that the entire application doesn’t crash due to a single component’s failure.

Note: Error boundaries only catch errors in the components below them in the tree, not within themselves. Therefore, it’s a good practice to place them at a high level in your component hierarchy, or around critical sections of your app.

### How does useEffect check changes in its array dependency?

The **useEffect** hook in React triggers side-effects in function components. One of its features is the dependency array, which you can provide to ensure that the effect runs only when the specified dependencies have changed between renders.

**useEffect** determines whether to re-run its effect based on a shallow comparison of the values inside the dependency array from the previous render to the current render.

#### Shallow Comparison

A shallow comparison checks if the values at corresponding indexes of the dependency array are the same between consecutive renders. It does not dive into nested objects or arrays, but checks only the top-level references. Here’s a breakdown:

- **Primitives:** For primitive values (like numbers, strings, or booleans), it checks if they are the same.
- **Objects and Arrays:** For objects and arrays, it checks the reference, not the content. If you create a new object or array every render, even with the same content, it will cause the effect to run every time.

```
const [count, setCount] = React.useState(0);

// This effect will run on every render,
// because a new array is created every time
useEffect(() => {
  console.log('This will run every render');
}, [count, []]);

// This effect will run only when 'count' changes,
// as the dependency array contains only primitive values
useEffect(() => {
  console.log('This will run when count changes');
}, [count]);
```

It’s crucial to ensure that objects or arrays passed to the dependency array have stable identities across renders, especially if their contents aren’t changing. Otherwise, it could lead to unnecessary effect runs. Using state setters, useMemo, or useCallback can help maintain stable object or function references across renders.
