import React, { useEffect, useState } from "react";

const Clock = props => {
  const [date, setDate] = useState(new Date());
  const interval = setInterval(() => setDate(new Date()), 1000);

  useEffect(() => {
    return () => clearInterval(interval);
  }, []);

  return <h2>It's {date.toLocaleTimeString()}</h2>;
};

export default Clock;
